using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;

namespace ModLab.Setup
{
    public sealed class PackageFile
    {
        public string Name { get; set; }
        public string RelativePath { get; set; }
        public string SHA256 { get; set; }
        public long Bytes { get; set; }
    }

    public sealed class OriginalFile
    {
        public string Path { get; set; }
        public string Backup { get; set; }
        public string SHA256 { get; set; }
    }

    public sealed class PackageManifest
    {
        public int Schema { get; set; }
        public string Profile { get; set; }
        public string Version { get; set; }
        public long SteamBuild { get; set; }
        public PackageFile[] Files { get; set; }
    }

    public sealed class InstallationRecord
    {
        public int Schema { get; set; }
        public string Profile { get; set; }
        public string GameDirectory { get; set; }
        public string Version { get; set; }
        public PackageFile[] Installed { get; set; }
        public OriginalFile[] Originals { get; set; }
    }

    // The same restorable transaction as the original installer, executed in
    // managed code. No interpreter, downloaded code or policy changes are used.
    public sealed class NativeTransaction
    {
        static readonly Dictionary<string, string> Targets = new Dictionary<string, string>(StringComparer.Ordinal) {
            { "ModLabLoader_P.pak", @"ModLabLoader\ModLabLoader_P.pak" },
            { "ModLabLoader_P.ucas", @"ModLabLoader\ModLabLoader_P.ucas" },
            { "ModLabLoader_P.utoc", @"ModLabLoader\ModLabLoader_P.utoc" },
            { "QoLSuite_P.pak", @"QoLSuite\QoLSuite_P.pak" },
            { "QoLSuite_P.ucas", @"QoLSuite\QoLSuite_P.ucas" },
            { "QoLSuite_P.utoc", @"QoLSuite\QoLSuite_P.utoc" },
            { "ModLab.html", @"QoLSuite\ModLab.html" },
            { "BerserkerBuffs.png", @"QoLSuite\BerserkerBuffs.png" }
        };

        readonly string gameRoot, modsRoot, backupRoot, statePath, legacyPath;
        readonly JavaScriptSerializer json = new JavaScriptSerializer();

        public NativeTransaction(string game)
        {
            if (!Path.IsPathRooted(game)) throw new ArgumentException("Select an absolute game folder.");
            gameRoot = Path.GetFullPath(game).TrimEnd('\\', '/');
            modsRoot = Path.Combine(gameRoot, @"Dungeons\Content\Paks\~mods");
            backupRoot = Path.Combine(gameRoot, "ModLabBackups");
            statePath = Path.Combine(backupRoot, "ModLab.install.json");
            legacyPath = Path.Combine(backupRoot, "ModLabLoader.install.json");
        }

        static bool Same(string first, string second) { return String.Equals(first, second, StringComparison.OrdinalIgnoreCase); }
        static bool Exists(string path) { return File.Exists(path) || Directory.Exists(path); }
        static bool IsLoader(string name) { return Regex.IsMatch(name, @"^(BlueprintLoader|BetterBlueprintLoader)_P\.(pak|ucas|utoc)$", RegexOptions.IgnoreCase); }
        public static string Hash(string path)
        {
            using (var stream = File.OpenRead(path))
            using (var hash = SHA256.Create()) return BitConverter.ToString(hash.ComputeHash(stream)).Replace("-", "");
        }

        void AssertPath(string path, string root)
        {
            if (String.IsNullOrWhiteSpace(path) || !Path.IsPathRooted(path)) throw new InvalidDataException("Invalid installation path.");
            var absolute = Path.GetFullPath(path);
            if (!absolute.StartsWith(Path.GetFullPath(root).TrimEnd('\\', '/') + "\\", StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("Installation path is outside its owned directory.");
            for (var check = absolute; check != null && (Same(check, gameRoot) || check.StartsWith(gameRoot + "\\", StringComparison.OrdinalIgnoreCase));
                check = Path.GetDirectoryName(check))
                if (Exists(check) && (File.GetAttributes(check) & FileAttributes.ReparsePoint) != 0)
                    throw new InvalidDataException("Installation paths cannot be junctions or symbolic links.");
        }

        public static void AssertHash(string path, string expected)
        {
            if (expected == null || !Regex.IsMatch(expected, "^[a-fA-F0-9]{64}$") || !File.Exists(path) ||
                (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0 || !Same(Hash(path), expected))
                throw new InvalidDataException("File is missing or changed: " + path);
        }

        static void AssertEntries(PackageFile[] entries)
        {
            if (entries == null || entries.Length != Targets.Count || entries.Any(entry => entry == null || entry.Name == null) ||
                entries.Select(entry => entry.Name).Distinct(StringComparer.OrdinalIgnoreCase).Count() != Targets.Count)
                throw new InvalidDataException("Incomplete or duplicate ModLab package records.");
            foreach (var entry in entries)
                if (!Targets.ContainsKey(entry.Name) || entry.RelativePath != Targets[entry.Name])
                    throw new InvalidDataException("Unexpected ModLab package filename or destination.");
        }

        static void AssertOriginals(OriginalFile[] originals)
        {
            if (originals == null || originals.Any(entry => entry == null || String.IsNullOrWhiteSpace(entry.Path)) ||
                originals.Select(entry => entry.Path).Distinct(StringComparer.OrdinalIgnoreCase).Count() != originals.Length)
                throw new InvalidDataException("Missing or duplicate original package records.");
        }

        void AssertOriginal(OriginalFile original)
        {
            AssertPath(original.Backup, backupRoot);
            bool runtime = Targets.Values.Any(relative => Same(original.Path, Path.Combine(modsRoot, relative)));
            if (Same(original.Path, legacyPath)) AssertPath(original.Path, backupRoot);
            else
            {
                AssertPath(original.Path, modsRoot);
                if (!runtime && !IsLoader(Path.GetFileName(original.Path))) throw new InvalidDataException("Unexpected original package record.");
            }
            AssertHash(original.Backup, original.SHA256);
            if (!runtime && Exists(original.Path)) throw new InvalidDataException("An original installation location is occupied by another package.");
        }

        T Read<T>(string path) { return json.Deserialize<T>(File.ReadAllText(path, Encoding.UTF8)); }
        static void WriteNew(string path, string text)
        {
            using (var stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            using (var writer = new StreamWriter(stream, new UTF8Encoding(false))) writer.Write(text);
        }

        static void CopyNew(string source, string destination, Action created = null)
        {
            using (var input = File.OpenRead(source))
            using (var output = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                if (created != null) created();
                input.CopyTo(output);
            }
        }

        static void AssertClosed()
        {
            foreach (var name in new[] { "Dungeons-Win64-Shipping", "Dungeons" })
                foreach (var process in Process.GetProcessesByName(name))
                    using (process)
                    {
                        try { if (!process.HasExited) throw new InvalidOperationException("Close Minecraft Dungeons II before installing, updating or removing ModLab."); }
                        catch (System.ComponentModel.Win32Exception) { throw new InvalidOperationException("Cannot verify that Minecraft Dungeons II is closed."); }
                    }
        }

        List<string> FindConflicts(InstallationRecord state)
        {
            var conflicts = new List<string>();
            if (!Directory.Exists(modsRoot)) return conflicts;
            var pending = new Stack<string>(); pending.Push(modsRoot);
            while (pending.Count > 0)
            {
                var directory = pending.Pop();
                foreach (var entry in Directory.EnumerateFileSystemEntries(directory))
                {
                    AssertPath(entry, modsRoot);
                    var attributes = File.GetAttributes(entry);
                    if ((attributes & FileAttributes.Directory) != 0) { pending.Push(entry); continue; }
                    var name = Path.GetFileName(entry);
                    if (IsLoader(name)) conflicts.Add(entry);
                    if (Regex.IsMatch(name, @"^(ModLabLoader|QoLSuite)_P\.(pak|ucas|utoc)$", RegexOptions.IgnoreCase) &&
                        !Targets.Any(target => Same(target.Key, name) && Same(entry, Path.Combine(modsRoot, target.Value))))
                        throw new InvalidDataException("A duplicate ModLab package is installed in another mods folder.");
                }
            }
            if (conflicts.Select(Path.GetFileName).Distinct(StringComparer.OrdinalIgnoreCase).Count() != conflicts.Count)
                throw new InvalidDataException("Duplicate conflicting loaders found. Resolve their duplicate packages first.");
            if (state != null && conflicts.Count > 0) throw new InvalidDataException("Another Blueprint loader was installed after ModLab. Resolve that conflict first.");
            return conflicts;
        }

        public string Apply(string operation, string packageDirectory)
        {
            if (operation != "Install" && operation != "Restore") throw new ArgumentException("Unknown operation.");
            string lockHash;
            using (var algorithm = SHA256.Create())
                lockHash = BitConverter.ToString(algorithm.ComputeHash(Encoding.UTF8.GetBytes(gameRoot.ToLowerInvariant()))).Replace("-", "");
            // Shares ownership with the previous PowerShell and standalone installers.
            using (var mutex = new Mutex(false, @"Local\ModLabLoader-" + lockHash))
            {
                bool locked = false;
                try
                {
                    try { locked = mutex.WaitOne(0); } catch (AbandonedMutexException) { locked = true; }
                    if (!locked) throw new InvalidOperationException("Another ModLab installer is already changing this game folder.");
                    return Execute(operation, packageDirectory);
                }
                finally { if (locked) mutex.ReleaseMutex(); }
            }
        }

        string Execute(string operation, string packageDirectory)
        {
            AssertClosed();
            if (!SteamDiscovery.HasGameFiles(gameRoot)) throw new ArgumentException("Select the Minecraft Dungeons II game folder containing Dungeons.");
            AssertPath(statePath, backupRoot); AssertPath(legacyPath, backupRoot);
            foreach (var relative in Targets.Values) AssertPath(Path.Combine(modsRoot, relative), modsRoot);
            InstallationRecord state = null;
            if (Exists(statePath))
            {
                state = Read<InstallationRecord>(statePath);
                if (state == null || state.Schema != 1 || state.Profile != "ModLab" || !Same(state.GameDirectory, gameRoot))
                    throw new InvalidDataException("ModLab installation record belongs to another package or game folder.");
                AssertEntries(state.Installed); AssertOriginals(state.Originals);
                foreach (var entry in state.Installed) AssertHash(Path.Combine(modsRoot, entry.RelativePath), entry.SHA256);
                foreach (var original in state.Originals) AssertOriginal(original);
                if (Exists(legacyPath)) throw new InvalidDataException("A standalone loader installation now conflicts with the combined ModLab installation.");
            }
            if (operation == "Restore" && state == null) throw new InvalidDataException("No owned ModLab installation to remove or restore.");
            PackageManifest manifest = null;
            if (operation == "Install")
            {
                manifest = Read<PackageManifest>(Path.Combine(packageDirectory, "ModLab.manifest.json"));
                if (manifest == null || manifest.Schema != 1 || manifest.Profile != "ModLab" || manifest.SteamBuild != 25754144 ||
                    manifest.Version == null || !Regex.IsMatch(manifest.Version, @"^\d+\.\d+\.\d+$"))
                    throw new InvalidDataException("Unsupported ModLab package manifest.");
                AssertEntries(manifest.Files);
                foreach (var entry in manifest.Files)
                {
                    string source = Path.Combine(packageDirectory, entry.Name);
                    AssertHash(source, entry.SHA256);
                    if (new FileInfo(source).Length != entry.Bytes) throw new InvalidDataException("Package file size does not match its manifest.");
                }
                if (SteamDiscovery.Build(gameRoot) != "25754144") throw new InvalidDataException("This alpha supports Steam build 25754144 only.");
            }
            var conflicts = FindConflicts(state);
            if (state == null && Exists(legacyPath))
            {
                var legacy = Read<InstallationRecord>(legacyPath);
                if (legacy == null || legacy.Schema != 1 || !Same(legacy.GameDirectory, gameRoot) || legacy.Installed == null ||
                    legacy.Installed.Length != 3 || legacy.Installed.Any(entry => entry == null || entry.Name == null) ||
                    legacy.Installed.Select(entry => entry.Name).Distinct(StringComparer.OrdinalIgnoreCase).Count() != 3)
                    throw new InvalidDataException("Invalid standalone loader installation record.");
                foreach (var entry in legacy.Installed)
                {
                    if (!Targets.ContainsKey(entry.Name) || !entry.Name.StartsWith("ModLabLoader_P.", StringComparison.Ordinal))
                        throw new InvalidDataException("Unexpected standalone loader package.");
                    AssertHash(Path.Combine(modsRoot, Targets[entry.Name]), entry.SHA256);
                }
                AssertOriginals(legacy.Originals);
                foreach (var original in legacy.Originals)
                {
                    if (!IsLoader(Path.GetFileName(original.Path))) throw new InvalidDataException("Unexpected standalone backup filename.");
                    AssertOriginal(original);
                }
            }
            Directory.CreateDirectory(backupRoot);
            var transaction = Path.Combine(backupRoot, "ModLab-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N"));
            AssertPath(transaction, backupRoot); Directory.CreateDirectory(transaction);
            var staged = Path.Combine(transaction, "Staged");
            if (operation == "Install")
            {
                Directory.CreateDirectory(staged);
                foreach (var entry in manifest.Files)
                {
                    var destination = Path.Combine(staged, entry.Name);
                    CopyNew(Path.Combine(packageDirectory, entry.Name), destination); AssertHash(destination, entry.SHA256);
                }
            }
            AssertClosed();
            var moved = new List<OriginalFile>(); var created = new List<string>();
            var originals = state == null ? new List<OriginalFile>() : state.Originals.ToList();
            bool stateMoved = false, stateCommitted = false;
            try
            {
                var existing = Targets.Values.Select(relative => Path.Combine(modsRoot, relative)).Where(Exists).ToList();
                if (state == null) { existing.AddRange(conflicts); if (Exists(legacyPath)) existing.Add(legacyPath); }
                foreach (var path in existing)
                {
                    var record = new OriginalFile { Path = path, Backup = Path.Combine(transaction, Path.GetFileName(path)), SHA256 = Hash(path) };
                    File.Move(path, record.Backup); moved.Add(record); if (state == null) originals.Add(record);
                    AssertHash(record.Backup, record.SHA256);
                }
                if (operation == "Install")
                {
                    foreach (var entry in manifest.Files)
                    {
                        var path = Path.Combine(modsRoot, entry.RelativePath); AssertPath(path, modsRoot);
                        Directory.CreateDirectory(Path.GetDirectoryName(path));
                        File.Move(Path.Combine(staged, entry.Name), path); created.Add(path); AssertHash(path, entry.SHA256);
                    }
                    var next = new InstallationRecord { Schema = 1, Profile = "ModLab", GameDirectory = gameRoot,
                        Version = manifest.Version, Originals = originals.ToArray(), Installed = manifest.Files };
                    var nextPath = Path.Combine(transaction, "next-install.json"); WriteNew(nextPath, json.Serialize(next));
                    if (state != null) { File.Move(statePath, Path.Combine(transaction, "previous-install.json")); stateMoved = true; }
                    File.Move(nextPath, statePath); stateCommitted = true;
                    return "ModLab installed. Start the game through Steam and press F10.\r\nBackup: " + transaction;
                }
                foreach (var original in originals)
                {
                    AssertPath(original.Path, Same(original.Path, legacyPath) ? backupRoot : modsRoot);
                    Directory.CreateDirectory(Path.GetDirectoryName(original.Path));
                    if (Exists(original.Path)) throw new IOException("An original destination is occupied.");
                    // Track only after CreateNew succeeds, including partial copies.
                    CopyNew(original.Backup, original.Path, () => created.Add(original.Path)); AssertHash(original.Path, original.SHA256);
                }
                File.Move(statePath, Path.Combine(transaction, "previous-install.json")); stateMoved = true;
                return "ModLab removed. The previous installation was restored. Settings and character saves were not changed.\r\nBackup: " + transaction;
            }
            catch (Exception failure)
            {
                try
                {
                    if (stateCommitted) File.Move(statePath, Path.Combine(transaction, "rollback-install.json"));
                    foreach (var path in created)
                        if (Exists(path)) File.Move(path, Path.Combine(transaction, "rollback-" + Path.GetFileName(path)));
                    foreach (var record in moved) { CopyNew(record.Backup, record.Path); AssertHash(record.Path, record.SHA256); }
                    if (stateMoved) CopyNew(Path.Combine(transaction, "previous-install.json"), statePath);
                }
                catch (Exception rollback)
                {
                    throw new IOException("Installation failed and rollback needs recovery from " + transaction + ". Rollback: " + rollback.Message + ". Original failure: " + failure.Message, rollback);
                }
                throw;
            }
        }
    }
}
