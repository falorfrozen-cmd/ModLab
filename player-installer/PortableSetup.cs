using System;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace ModLab.Setup
{
    // A normal desktop installer distributed beside its verified data files.
    // It does not unpack an executable, launch a helper, or download anything.
    public static class PortableSetup
    {
        public static string PackageDirectory
        {
            get { return Path.Combine(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location), "Package"); }
        }

        public static string Apply(string operation, string game)
        {
            NativeTransaction.AssertHash(Path.Combine(PackageDirectory, "ModLab.manifest.json"), BuildIdentity.ManifestSha256);
            return new NativeTransaction(game).Apply(operation, PackageDirectory);
        }

        [STAThread]
        public static int Main(string[] args)
        {
            AppContext.SetSwitch("Switch.System.IO.UseLegacyPathHandling", false);
            AppContext.SetSwitch("Switch.System.IO.BlockLongPaths", false);
            if (args.Length != 0) return RunCommand(args);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SetupWindow());
            return 0;
        }

        static int RunCommand(string[] args)
        {
            string resultPath = null;
            bool mayWrite = false;
            try
            {
                if (args.Length != 4 || args[0] != "--worker" || (args[1] != "Install" && args[1] != "Restore"))
                    throw new ArgumentException("Expected --worker Install|Restore <absolute game folder> <new temporary result.json>.");
                resultPath = Path.GetFullPath(args[3]);
                var resultDirectory = Path.GetDirectoryName(resultPath);
                if (!Path.IsPathRooted(args[3]) || Path.GetFileName(resultPath) != "result.json" ||
                    !resultPath.StartsWith(Path.GetFullPath(Path.GetTempPath()).TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase) ||
                    !Directory.Exists(resultDirectory))
                    throw new ArgumentException("Use a new result.json inside an existing temporary test directory.");
                for (var check = resultDirectory; check != null; check = Path.GetDirectoryName(check))
                    if ((File.GetAttributes(check) & FileAttributes.ReparsePoint) != 0)
                        throw new IOException("The result directory cannot use junctions or symbolic links.");
                if (File.Exists(resultPath) || Directory.Exists(resultPath))
                    throw new IOException("The result destination is already occupied.");
                mayWrite = true;
                var detail = Apply(args[1], args[2]);
                WriteResult(resultPath, true, detail);
                return 0;
            }
            catch (Exception error)
            {
                if (mayWrite)
                    try { WriteResult(resultPath, false, error.ToString()); }
                    catch (IOException) { }
                    catch (UnauthorizedAccessException) { }
                return 1;
            }
        }

        static void WriteResult(string path, bool success, string detail)
        {
            var text = new JavaScriptSerializer().Serialize(new { Success = success, Message = detail, Details = detail });
            using (var output = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            using (var writer = new StreamWriter(output, new UTF8Encoding(false))) writer.Write(text);
        }
    }

    public sealed class SetupWindow : Form
    {
        readonly ComboBox games = new ComboBox();
        readonly TextBox gamePath = new TextBox();
        readonly ComboBox operation = new ComboBox();
        readonly TextBox log = new TextBox();
        readonly Button apply = new Button();
        readonly Button browse = new Button();
        readonly Label status = new Label();
        bool changingFiles;

        public SetupWindow()
        {
            Text = "ModLab Setup";
            ClientSize = new Size(700, 560);
            MinimumSize = new Size(640, 560);
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.Dpi;
            BackColor = Color.FromArgb(15, 28, 39);
            ForeColor = Color.FromArgb(227, 236, 242);
            Font = new Font("Segoe UI", 10);
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(24), ColumnCount = 2, RowCount = 10 };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 100));
            foreach (var height in new[] { 48, 48, 28, 32, 36, 28, 36, 48, 0, 36 })
                layout.RowStyles.Add(height == 0 ? new RowStyle(SizeType.Percent, 100) : new RowStyle(SizeType.Absolute, height));
            Controls.Add(layout);
            AddWide(layout, new Label { Text = "MODLAB", Dock = DockStyle.Fill, Font = new Font("Segoe UI", 24, FontStyle.Bold), ForeColor = Color.FromArgb(76, 220, 227) }, 0);
            AddWide(layout, new Label { Text = "Minecraft Dungeons II  ·  " + BuildIdentity.Version + "\r\nInstall the complete suite. Original files are backed up before changes.", Dock = DockStyle.Fill }, 1);
            AddWide(layout, new Label { Text = "Steam library", Dock = DockStyle.Fill }, 2);
            games.DropDownStyle = ComboBoxStyle.DropDownList;
            games.Dock = DockStyle.Fill;
            games.SelectedIndexChanged += delegate { if (games.SelectedItem != null) gamePath.Text = games.SelectedItem.ToString(); };
            AddWide(layout, games, 3);
            gamePath.Dock = DockStyle.Fill;
            layout.Controls.Add(gamePath, 0, 4);
            browse.Text = "Browse…";
            browse.Dock = DockStyle.Fill;
            browse.Click += delegate
            {
                using (var dialog = new FolderBrowserDialog { Description = "Select the game folder containing Dungeons", SelectedPath = gamePath.Text })
                    if (dialog.ShowDialog(this) == DialogResult.OK) gamePath.Text = dialog.SelectedPath;
            };
            layout.Controls.Add(browse, 1, 4);
            AddWide(layout, new Label { Text = "Operation", Dock = DockStyle.Fill }, 5);
            operation.DropDownStyle = ComboBoxStyle.DropDownList;
            operation.Items.AddRange(new object[] { "Install / Update ModLab", "Remove / Restore previous installation" });
            operation.SelectedIndex = 0;
            operation.Dock = DockStyle.Fill;
            AddWide(layout, operation, 6);
            AddWide(layout, new Label { Text = "Close the game first. Supports Steam build 25754144 / game 1.1.2.0.\r\nFor protected game folders, start ModLab.exe with Run as administrator.", Dock = DockStyle.Fill, ForeColor = Color.FromArgb(181, 204, 216) }, 7);
            log.Dock = DockStyle.Fill;
            log.Multiline = true;
            log.ReadOnly = true;
            log.ScrollBars = ScrollBars.Vertical;
            log.BackColor = Color.FromArgb(8, 20, 29);
            log.ForeColor = ForeColor;
            AddWide(layout, log, 8);
            status.Dock = DockStyle.Fill;
            status.Text = "Your character saves and other mods are preserved.";
            layout.Controls.Add(status, 0, 9);
            apply.Text = "Apply";
            apply.Dock = DockStyle.Fill;
            apply.Click += ApplyClicked;
            layout.Controls.Add(apply, 1, 9);
            FormClosing += delegate(object sender, FormClosingEventArgs args) { if (changingFiles) args.Cancel = true; };
            Shown += async delegate
            {
                try
                {
                    var detected = await Task.Run(() => SteamDiscovery.Discover());
                    games.Items.AddRange(detected.ToArray());
                    if (games.Items.Count > 0) games.SelectedIndex = 0;
                }
                catch (Exception error) { log.AppendText("Automatic detection: " + error.Message + "\r\nUse Browse to select your game.\r\n"); }
                try
                {
                    NativeTransaction.AssertHash(Path.Combine(PortableSetup.PackageDirectory, "ModLab.manifest.json"), BuildIdentity.ManifestSha256);
                }
                catch (Exception error)
                {
                    apply.Enabled = false;
                    log.AppendText(error.Message + "\r\nExtract the complete ZIP before running ModLab.exe.\r\n");
                }
            };
        }

        static void AddWide(TableLayoutPanel layout, Control control, int row)
        {
            layout.Controls.Add(control, 0, row);
            layout.SetColumnSpan(control, 2);
        }

        async void ApplyClicked(object sender, EventArgs args)
        {
            if (changingFiles) return;
            var selectedGame = gamePath.Text.Trim();
            var selectedOperation = operation.SelectedIndex == 1 ? "Restore" : "Install";
            if (!Path.IsPathRooted(selectedGame) || !SteamDiscovery.HasGameFiles(selectedGame))
            {
                MessageBox.Show(this, "Select the game folder containing Dungeons.", "ModLab", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if (MessageBox.Show(this, operation.SelectedItem + "\r\n\r\n" + selectedGame + "\r\n\r\nOriginal files will be preserved in ModLabBackups.", "ModLab", MessageBoxButtons.OKCancel, MessageBoxIcon.Information) != DialogResult.OK) return;
            changingFiles = true;
            apply.Enabled = browse.Enabled = games.Enabled = gamePath.Enabled = operation.Enabled = false;
            status.Text = "Working…";
            try
            {
                var detail = await Task.Run(() => PortableSetup.Apply(selectedOperation, selectedGame));
                log.AppendText(detail + "\r\n");
                status.Text = "Completed.";
            }
            catch (Exception error)
            {
                log.AppendText(error.ToString() + "\r\n");
                status.Text = "Operation failed. See details above.";
                MessageBox.Show(this, error.Message, "ModLab", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                changingFiles = false;
                apply.Enabled = browse.Enabled = games.Enabled = gamePath.Enabled = operation.Enabled = true;
            }
        }
    }
}
