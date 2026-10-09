using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

namespace ModLabLoader.Setup
{
    public sealed class OperationResult
    {
        public bool Success { get; set; }
        public string Message { get; set; }
        public string Details { get; set; }
    }

    // Detection reads Steam metadata only. It does not scan disks or player saves.
    public static class SteamDiscovery
    {
        public static string Value(string text, string key)
        {
            var match = Regex.Match(text, "\"" + Regex.Escape(key) + "\"\\s+\"((?:\\\\.|[^\"\\\\])*)\"", RegexOptions.IgnoreCase);
            return match.Success ? Unescape(match.Groups[1].Value) : null;
        }

        static string Unescape(string text)
        {
            return text.Replace("\\\\", "\\").Replace("\\\"", "\"");
        }

        public static IEnumerable<string> LibraryPaths(string text)
        {
            foreach (Match match in Regex.Matches(text, "\"(?:path|[0-9]+)\"\\s+\"((?:\\\\.|[^\"\\\\])*)\"", RegexOptions.IgnoreCase))
            {
                var path = Unescape(match.Groups[1].Value);
                if (Path.IsPathRooted(path)) yield return path;
            }
        }

        public static List<string> Discover(IEnumerable<string> roots)
        {
            var libraries = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var root in roots.Where(p => !String.IsNullOrWhiteSpace(p)))
            {
                try
                {
                    libraries.Add(Path.GetFullPath(root));
                    var metadata = Path.Combine(root, "steamapps", "libraryfolders.vdf");
                    if (File.Exists(metadata))
                        foreach (var path in LibraryPaths(File.ReadAllText(metadata))) libraries.Add(Path.GetFullPath(path));
                }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
                catch (ArgumentException) { }
            }
            var games = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var library in libraries)
            {
                try
                {
                    var manifest = Path.Combine(library, "steamapps", "appmanifest_1912410.acf");
                    if (!File.Exists(manifest)) continue;
                    var metadata = File.ReadAllText(manifest);
                    if (Value(metadata, "appid") != "1912410") continue;
                    var name = Value(metadata, "installdir");
                    if (String.IsNullOrWhiteSpace(name) || name != Path.GetFileName(name) || name == "." || name == "..") continue;
                    var game = Path.Combine(library, "steamapps", "common", name);
                    if (HasGameFiles(game)) games.Add(Path.GetFullPath(game));
                }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
                catch (ArgumentException) { }
            }
            return games.OrderBy(p => p, StringComparer.OrdinalIgnoreCase).ToList();
        }

        public static List<string> Discover()
        {
            var roots = new List<string>();
            foreach (var view in new[] { RegistryView.Registry32, RegistryView.Registry64 })
                foreach (var hive in new[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine })
                    using (var registry = RegistryKey.OpenBaseKey(hive, view))
                    using (var steam = registry.OpenSubKey(@"SOFTWARE\Valve\Steam"))
                        if (steam != null)
                            foreach (var name in new[] { "SteamPath", "InstallPath" })
                            {
                                var path = steam.GetValue(name) as string;
                                if (!String.IsNullOrWhiteSpace(path)) roots.Add(path);
                            }
            roots.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Steam"));
            return Discover(roots);
        }

        public static bool HasGameFiles(string game)
        {
            return File.Exists(Path.Combine(game, @"Dungeons\Content\Paks\global.utoc")) &&
                File.Exists(Path.Combine(game, @"Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe"));
        }

        public static string Build(string game)
        {
            var parent = Directory.GetParent(Path.GetFullPath(game));
            if (parent == null || parent.Parent == null) return null;
            var path = Path.Combine(parent.Parent.FullName, "appmanifest_1912410.acf");
            if (!File.Exists(path)) return null;
            var text = File.ReadAllText(path);
            return Value(text, "appid") == "1912410" ? Value(text, "buildid") : null;
        }

        public static bool CompleteModLabInstalled(string game)
        {
            return File.Exists(Path.Combine(game, @"ModLabBackups\ModLab.install.json"));
        }
    }

    public static class InstallEngine
    {
        static readonly string[] PayloadNames = {
            "install_modlab_loader.ps1", "ModLabLoader.manifest.json", "ModLabLoader_P.pak",
            "ModLabLoader_P.ucas", "ModLabLoader_P.utoc", "NeoRune-LICENSE.txt", "LICENSE", "THIRD-PARTY-NOTICES.md"
        };

        public static string Licenses()
        {
            using (var resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("ModLabLoader.Payload.zip"))
            using (var archive = new ZipArchive(resource, ZipArchiveMode.Read))
            {
                var text = new StringBuilder();
                foreach (var name in new[] { "LICENSE", "NeoRune-LICENSE.txt", "THIRD-PARTY-NOTICES.md" })
                    using (var reader = new StreamReader(archive.GetEntry(name).Open()))
                        text.AppendLine(name).AppendLine().AppendLine(reader.ReadToEnd()).AppendLine();
                return text.ToString();
            }
        }

        public static string Quote(string value)
        {
            // Windows CommandLineToArgvW escaping, not shell or PowerShell code.
            var quoted = new StringBuilder("\"");
            int slashes = 0;
            foreach (char c in value)
            {
                if (c == '\\') { slashes++; continue; }
                if (c == '"') quoted.Append('\\', slashes * 2 + 1);
                else quoted.Append('\\', slashes);
                quoted.Append(c); slashes = 0;
            }
            return quoted.Append('\\', slashes * 2).Append('"').ToString();
        }

        public static OperationResult Apply(string operation, string game)
        {
            string scratch = Path.Combine(Path.GetTempPath(), "ModLabLoader-payload-" + Guid.NewGuid().ToString("N"));
            var result = new OperationResult { Success = false };
            try
            {
                if (operation != "Install" && operation != "Restore") throw new ArgumentException("Unknown operation.");
                if (!Path.IsPathRooted(game)) throw new ArgumentException("Select an absolute game folder.");
                game = Path.GetFullPath(game).TrimEnd(Path.DirectorySeparatorChar);
                if (!SteamDiscovery.HasGameFiles(game)) throw new ArgumentException("Select the folder containing Dungeons. The selected folder has no game files.");
                if (SteamDiscovery.CompleteModLabInstalled(game))
                    throw new InvalidOperationException("ModLab Complete is already installed. Use the combined ModLab-Setup installer for updates or removal. Do not manually remove the loader or its backups.");
                if (operation == "Install" && SteamDiscovery.Build(game) != "25754144")
                    throw new ArgumentException("This experimental release supports Steam build 25754144 only. The selected build is not supported.");
                Directory.CreateDirectory(scratch);
                using (var resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("ModLabLoader.Payload.zip"))
                {
                    if (resource == null) throw new InvalidDataException("The embedded loader package is missing.");
                    using (var hash = SHA256.Create())
                    {
                        if (BitConverter.ToString(hash.ComputeHash(resource)).Replace("-", "") != BuildIdentity.PayloadSha256)
                            throw new InvalidDataException("The embedded loader package failed verification.");
                    }
                    resource.Position = 0;
                    using (var archive = new ZipArchive(resource, ZipArchiveMode.Read))
                    {
                        if (archive.Entries.Count != PayloadNames.Length) throw new InvalidDataException("Unexpected package contents.");
                        var extracted = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                        foreach (var entry in archive.Entries)
                        {
                            if (!PayloadNames.Contains(entry.FullName) || !extracted.Add(entry.FullName))
                                throw new InvalidDataException("Unexpected or duplicate package entry.");
                            using (var input = entry.Open())
                            using (var output = new FileStream(Path.Combine(scratch, entry.FullName), FileMode.CreateNew)) input.CopyTo(output);
                        }
                    }
                }
                var script = Path.Combine(scratch, "install_modlab_loader.ps1");
                var powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
                var command = new ProcessStartInfo(powershell,
                    "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + Quote(script) +
                    " -GameDirectory " + Quote(game) + " -PackageDirectory " + Quote(scratch) + " -Operation " + operation)
                {
                    UseShellExecute = false, CreateNoWindow = true,
                    RedirectStandardOutput = true, RedirectStandardError = true,
                    StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8
                };
                // A PowerShell 7 parent may export its own module search path.
                // The Windows 5.1 helper needs the modules shipped with Windows.
                command.EnvironmentVariables["PSModulePath"] = Path.Combine(Path.GetDirectoryName(powershell), "Modules");
                var transcript = new StringBuilder();
                using (var process = new Process { StartInfo = command })
                {
                    DataReceivedEventHandler capture = (sender, data) => {
                        if (data.Data != null) lock (transcript) transcript.AppendLine(data.Data);
                    };
                    process.OutputDataReceived += capture; process.ErrorDataReceived += capture;
                    process.Start(); process.BeginOutputReadLine(); process.BeginErrorReadLine();
                    // Do not terminate a filesystem transaction mid-copy or mid-rollback.
                    process.WaitForExit();
                    result.Details = transcript.ToString();
                    result.Success = process.ExitCode == 0;
                }
                result.Message = result.Success ? (operation == "Install" ?
                    "ModLab Loader is installed. Start the game normally through Steam." :
                    "ModLab Loader was removed. Any loader backed up during installation was restored.") :
                    "The operation did not complete. See Details for the reason. Do not change loader files while the game is running.";
            }
            catch (Exception error)
            {
                result.Message = error.Message; result.Details = error.ToString();
            }
            finally
            {
                // Only this extraction's allowlisted files are removed. Never recursively delete.
                foreach (var name in PayloadNames)
                    try { var path = Path.Combine(scratch, name); if (File.Exists(path)) File.Delete(path); } catch (IOException) { } catch (UnauthorizedAccessException) { }
                try { if (Directory.Exists(scratch)) Directory.Delete(scratch, false); } catch (IOException) { } catch (UnauthorizedAccessException) { }
            }
            return result;
        }

        public static void AssertWorkerResultPath(string path)
        {
            path = Path.GetFullPath(path);
            var parent = Directory.GetParent(path);
            var prefix = Path.GetFullPath(Path.GetTempPath()).TrimEnd('\\') + "\\";
            // A credential-based UAC worker can have a different current-user Temp.
            bool inTemp = path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ||
                Regex.IsMatch(path, @"^[A-Za-z]:\\Users\\[^\\]+\\AppData\\Local\\Temp\\ModLabLoader-run-[a-f0-9]{32}\\result\.json$", RegexOptions.IgnoreCase);
            if (parent == null || !inTemp ||
                !Regex.IsMatch(parent.Name, "^ModLabLoader-run-[a-f0-9]{32}$") || Path.GetFileName(path) != "result.json" ||
                !parent.Exists || File.Exists(path) || (parent.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new ArgumentException("Invalid worker result location.");
        }
    }

    public sealed class InstallerWindow : Form
    {
        readonly Color ink = Color.FromArgb(222, 234, 243);
        readonly Color muted = Color.FromArgb(160, 179, 195);
        readonly ComboBox location = new ComboBox();
        readonly Label state = new Label();
        readonly Label outcome = new Label();
        readonly Button install = new Button();
        readonly Button restore = new Button();
        readonly Button browse = new Button();
        readonly Button refresh = new Button();
        readonly Button close = new Button();
        readonly TextBox details = new TextBox();
        readonly ProgressBar progress = new ProgressBar();
        bool busy;
        public bool RenderOnly;
        protected override bool ShowWithoutActivation { get { return RenderOnly; } }

        public InstallerWindow()
        {
            Text = "ModLab Loader Setup | " + BuildIdentity.Version;
            Font = new Font("Segoe UI", 10F); ForeColor = ink; BackColor = Color.FromArgb(15, 24, 35);
            AutoScaleDimensions = new SizeF(96, 96); AutoScaleMode = AutoScaleMode.Dpi;
            ClientSize = new Size(800, 750); MinimumSize = new Size(720, 750);
            StartPosition = FormStartPosition.CenterScreen;
            var page = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(28), ColumnCount = 1, RowCount = 10 };
            Controls.Add(page);
            float[] heights = { 62, 64, 36, 44, 44, 112, 54, 14, 0, 50 };
            for (int i = 0; i < heights.Length; i++)
                page.RowStyles.Add(new RowStyle(i == 8 ? SizeType.Percent : SizeType.Absolute, i == 8 ? 100 : heights[i]));
            page.Controls.Add(Label("ModLab Loader (standalone)", 25F, ink), 0, 0);
            page.Controls.Add(Label("EXPERIMENTAL  " + BuildIdentity.Version + "\nLoad Blueprint mods. Keep your installation reversible.", 10F, muted), 0, 1);
            page.Controls.Add(Label("Minecraft Dungeons II game folder", 11F, ink), 0, 2);
            var paths = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, Margin = new Padding(0) };
            paths.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            paths.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 100)); paths.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 96));
            location.Dock = DockStyle.Fill; location.Margin = new Padding(0, 4, 8, 0);
            location.AutoCompleteMode = AutoCompleteMode.SuggestAppend; location.AutoCompleteSource = AutoCompleteSource.ListItems;
            location.TextChanged += (sender, args) => RefreshState();
            ConfigureButton(browse, "Browse...", false); ConfigureButton(refresh, "Refresh", false);
            browse.Click += (sender, args) => { using (var dialog = new FolderBrowserDialog { Description = "Select the game folder containing Dungeons", ShowNewFolderButton = false })
                if (dialog.ShowDialog(this) == DialogResult.OK) location.Text = dialog.SelectedPath; };
            refresh.Click += (sender, args) => FindGames();
            paths.Controls.Add(location, 0, 0); paths.Controls.Add(browse, 1, 0); paths.Controls.Add(refresh, 2, 0);
            page.Controls.Add(paths, 0, 3);
            state.Dock = DockStyle.Fill; state.ForeColor = muted; state.Padding = new Padding(0, 8, 0, 0); page.Controls.Add(state, 0, 4);
            page.Controls.Add(Label("Steam build 25754144 / game 1.1.2.0\nInstall / Update backs up conflicting loaders outside Paks.\nRemove / Restore returns to the backed-up loader.\nCharacter saves stay untouched.", 10F, muted), 0, 5);
            var actions = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, Margin = new Padding(0) };
            actions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50)); actions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            ConfigureButton(install, "Install / Update", true); ConfigureButton(restore, "Remove / Restore", false);
            install.Click += async (sender, args) => await Apply("Install"); restore.Click += async (sender, args) => await Apply("Restore");
            actions.Controls.Add(install, 0, 0); actions.Controls.Add(restore, 1, 0); page.Controls.Add(actions, 0, 6);
            progress.Dock = DockStyle.Fill; progress.Visible = false; progress.Style = ProgressBarStyle.Marquee; page.Controls.Add(progress, 0, 7);
            var feedback = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, Margin = new Padding(0) };
            feedback.RowStyles.Add(new RowStyle(SizeType.Absolute, 66)); feedback.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            outcome.Dock = DockStyle.Fill; outcome.Padding = new Padding(0, 10, 0, 0); outcome.Text = "Close the game before installing or removing a loader.";
            details.Dock = DockStyle.Fill; details.Multiline = true; details.ReadOnly = true; details.ScrollBars = ScrollBars.Vertical;
            details.BackColor = Color.FromArgb(22, 34, 46); details.ForeColor = muted; details.BorderStyle = BorderStyle.FixedSingle;
            details.Text = "Details will appear here.\r\nThis installs the loader only. Gameplay mods are separate downloads.";
            feedback.Controls.Add(outcome, 0, 0); feedback.Controls.Add(details, 0, 1); page.Controls.Add(feedback, 0, 8);
            ConfigureButton(close, "Close", false); close.Width = 100; close.Dock = DockStyle.Right; close.Click += (sender, args) => Close();
            var footer = new Panel { Dock = DockStyle.Fill, Margin = new Padding(0) };
            var licenses = new LinkLabel { Text = "Licenses", AutoSize = true, LinkColor = muted, Location = new Point(0, 12) };
            licenses.Click += (sender, args) => {
                using (var licenseWindow = new Form { Text = "ModLab Loader licenses", ClientSize = new Size(680, 500), StartPosition = FormStartPosition.CenterParent })
                {
                    licenseWindow.Controls.Add(new TextBox { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical,
                        Font = new Font("Segoe UI", 10F), Text = InstallEngine.Licenses().Replace("\r\n", "\n").Replace("\n", "\r\n") });
                    licenseWindow.ShowDialog(this);
                }
            };
            footer.Controls.Add(close); footer.Controls.Add(licenses); page.Controls.Add(footer, 0, 9);
            var complete = new LinkLabel { Text = "Get complete ModLab (gameplay + loader)", AutoSize = true, LinkColor = muted, Location = new Point(100, 12) };
            complete.Click += (sender, args) => Process.Start(new ProcessStartInfo("https://github.com/falorfrozen-cmd/Minecraft-Dungeons-II-ModLab-Loader/releases/tag/modlab-v0.1.0-alpha.1") { UseShellExecute = true });
            footer.Controls.Add(complete);
            FormClosing += (sender, args) => { if (busy) { args.Cancel = true; outcome.Text = "Please wait for the installation transaction to finish."; } };
            FindGames();
        }

        Label Label(string text, float size, Color color)
        {
            return new Label { Text = text, Font = new Font("Segoe UI", size), ForeColor = color, Dock = DockStyle.Fill, Margin = new Padding(0), AutoEllipsis = true };
        }

        void ConfigureButton(Button button, string text, bool primary)
        {
            button.Text = text; button.Dock = DockStyle.Fill; button.FlatStyle = FlatStyle.Flat;
            button.Margin = new Padding(0, 0, 8, 8); button.FlatAppearance.BorderColor = Color.FromArgb(61, 86, 107);
            button.BackColor = primary ? Color.FromArgb(70, 220, 204) : Color.FromArgb(28, 46, 62);
            button.ForeColor = primary ? Color.FromArgb(12, 33, 41) : ink; button.UseVisualStyleBackColor = false;
        }

        void FindGames()
        {
            var selected = location.Text;
            location.Items.Clear(); foreach (var game in SteamDiscovery.Discover()) location.Items.Add(game);
            if (location.Items.Count > 0 && String.IsNullOrEmpty(selected)) location.SelectedIndex = 0;
            else location.Text = selected;
            RefreshState();
        }

        void RefreshState()
        {
            if (busy) return;
            bool valid = false, owned = false, complete = false;
            try
            {
                var game = location.Text.Trim();
                if (String.IsNullOrEmpty(game)) { state.Text = "No game selected. Browse to your Steam installation."; }
                else if (!Path.IsPathRooted(game) || !SteamDiscovery.HasGameFiles(game)) { state.Text = "Select the game root folder containing Dungeons."; }
                else
                {
                    var build = SteamDiscovery.Build(game); valid = build == "25754144";
                    owned = File.Exists(Path.Combine(game, @"ModLabBackups\ModLabLoader.install.json"));
                    complete = SteamDiscovery.CompleteModLabInstalled(game);
                    state.Text = complete ? "ModLab Complete is installed. Use the combined ModLab-Setup installer." :
                        (valid ? "Supported Steam build detected." : "Unsupported build: " + (build ?? "Steam manifest not found")) +
                        (owned ? "  ModLab Loader installation record found." : "");
                }
            }
            catch (Exception error) { state.Text = "Cannot read this folder: " + error.Message; }
            install.Enabled = valid && !complete; restore.Enabled = owned && !complete;
        }

        async Task Apply(string operation)
        {
            string game = location.Text.Trim(); busy = true;
            install.Enabled = restore.Enabled = browse.Enabled = refresh.Enabled = location.Enabled = close.Enabled = false;
            progress.Visible = true; outcome.Text = operation == "Install" ? "Installing the verified loader package..." : "Restoring the previous loader...";
            try
            {
                var result = await Task.Run(() => RunWorker(operation, game));
                outcome.Text = result.Message; outcome.ForeColor = result.Success ? Color.FromArgb(92, 227, 187) : Color.FromArgb(255, 174, 135);
                details.Text = result.Details ?? result.Message;
            }
            catch (System.ComponentModel.Win32Exception error)
            {
                outcome.Text = error.NativeErrorCode == 1223 ? "Administrator permission was cancelled. No installation was started." : error.Message;
                details.Text = error.ToString();
            }
            catch (Exception error) { outcome.Text = error.Message; details.Text = error.ToString(); }
            finally
            {
                busy = false; progress.Visible = false; browse.Enabled = refresh.Enabled = location.Enabled = close.Enabled = true; RefreshState();
            }
        }

        static OperationResult RunWorker(string operation, string game)
        {
            string run = Path.Combine(Path.GetTempPath(), "ModLabLoader-run-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(run); string resultPath = Path.Combine(run, "result.json");
            var identity = WindowsIdentity.GetCurrent();
            bool elevated = new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator);
            var start = new ProcessStartInfo(Assembly.GetExecutingAssembly().Location,
                "--worker " + operation + " " + InstallEngine.Quote(game) + " " + InstallEngine.Quote(resultPath))
            { UseShellExecute = !elevated, Verb = elevated ? "" : "runas", WindowStyle = ProcessWindowStyle.Hidden, CreateNoWindow = true };
            using (var process = Process.Start(start))
            {
                process.WaitForExit();
                if (!File.Exists(resultPath)) return new OperationResult { Success = false,
                    Message = "The installer worker could not return a result. No successful installation was reported.", Details = "Worker exit code: " + process.ExitCode };
                return new JavaScriptSerializer().Deserialize<OperationResult>(File.ReadAllText(resultPath));
            }
        }
    }

    public static class Program
    {
        [STAThread]
        public static int Main(string[] args)
        {
            AppContext.SetSwitch("Switch.System.IO.UseLegacyPathHandling", false);
            AppContext.SetSwitch("Switch.System.IO.BlockLongPaths", false);
            if (args.Length == 4 && args[0] == "--worker")
            {
                try
                {
                    InstallEngine.AssertWorkerResultPath(args[3]);
                    var result = InstallEngine.Apply(args[1], args[2]);
                    // CreateNew prevents an arbitrary pre-existing result file being overwritten.
                    using (var stream = new FileStream(args[3], FileMode.CreateNew))
                    using (var writer = new StreamWriter(stream, new UTF8Encoding(false))) writer.Write(new JavaScriptSerializer().Serialize(result));
                    return result.Success ? 0 : 1;
                }
                catch { return 2; }
            }
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            using (var window = new InstallerWindow())
            {
                if (args.Length == 2 && args[0] == "--render")
                {
                    window.RenderOnly = true; window.ShowInTaskbar = false;
                    window.StartPosition = FormStartPosition.Manual; window.Location = new Point(-30000, -30000);
                    window.Show(); Application.DoEvents(); window.PerformLayout();
                    using (var bitmap = new Bitmap(window.Width, window.Height))
                    { window.DrawToBitmap(bitmap, new Rectangle(Point.Empty, window.Size)); bitmap.Save(args[1], System.Drawing.Imaging.ImageFormat.Png); }
                    window.Hide();
                    return 0;
                }
                if (args.Length != 0) return 2;
                Application.Run(window);
            }
            return 0;
        }
    }
}
