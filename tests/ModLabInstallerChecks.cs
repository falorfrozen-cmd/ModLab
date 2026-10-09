using System;
using System.IO;
using System.Linq;
using System.Diagnostics;
using System.Reflection;
using System.Threading;
using System.Web.Script.Serialization;
using ModLab.Setup;

public static class InstallerChecks
{
    static int passed;
    static void Check(bool value, string name) { if (!value) throw new Exception(name); passed++; }
    static void Rejected(Action operation, string message)
    {
        try { operation(); } catch (Exception error) { Check(error.Message.Contains(message), "Wrong rejection: " + error); return; }
        throw new Exception("Expected rejection: " + message);
    }
    public static int Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--hold-game")
        {
            using (var signal = EventWaitHandle.OpenExisting(args[1])) signal.WaitOne();
            return 0;
        }
        AppContext.SetSwitch("Switch.System.IO.UseLegacyPathHandling", false);
        AppContext.SetSwitch("Switch.System.IO.BlockLongPaths", false);
        var root = args[0]; Directory.CreateDirectory(root);
        var main = Path.Combine(root, "Main Steam");
        var library = Path.Combine(root, "Library With Spaces ü");
        var nested = Path.Combine(library, "steamapps", "common", "A Custom Install Name");
        Directory.CreateDirectory(Path.Combine(main, "steamapps"));
        Directory.CreateDirectory(Path.Combine(nested, @"Dungeons\Content\Paks"));
        Directory.CreateDirectory(Path.Combine(nested, @"Dungeons\Binaries\Win64"));
        File.WriteAllText(Path.Combine(nested, @"Dungeons\Content\Paks\global.utoc"), "fixture");
        File.WriteAllText(Path.Combine(nested, @"Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe"), "fixture");
        var escaped = library.Replace("\\", "\\\\");
        var modern = "\"libraryfolders\" { \"1\" { \"path\" \"" + escaped + "\" \"apps\" { \"1912410\" \"9\" } } }";
        File.WriteAllText(Path.Combine(main, @"steamapps\libraryfolders.vdf"), modern);
        var manifest = Path.Combine(library, @"steamapps\appmanifest_1912410.acf");
        File.WriteAllText(manifest, "\"AppState\" { \"appid\" \"1912410\" \"installdir\" \"A Custom Install Name\" \"buildid\" \"25754144\" }");
        var found = SteamDiscovery.Discover(new[] { main, main.ToUpperInvariant() });
        Check(found.Count == 1 && found[0] == nested, "Secondary library detection or deduplication failed.");
        Check(SteamDiscovery.Build(nested) == "25754144", "Supported build not read.");
        Check(SteamDiscovery.LibraryPaths(modern).Count() == 1, "Modern library metadata misread.");
        Check(SteamDiscovery.LibraryPaths("\"1\" \"" + escaped + "\"").Single() == library, "Legacy library metadata misread.");
        Check(!SteamDiscovery.LibraryPaths("\"1\" \"relative\"").Any(), "Relative library accepted.");
        File.WriteAllText(manifest, "\"appid\" \"99\" \"installdir\" \"A Custom Install Name\" \"buildid\" \"25754144\"");
        Check(!SteamDiscovery.Discover(new[] { main }).Any(), "Wrong Steam app accepted.");
        Check(SteamDiscovery.Build(nested) == null, "Wrong app's build accepted.");
        File.WriteAllText(manifest, "\"appid\" \"1912410\" \"installdir\" \"..\\..\\outside\"");
        Check(!SteamDiscovery.Discover(new[] { main }).Any(), "Manifest path traversal accepted.");
        Check(InstallEngine.Quote("D:\\test folder\\") == "\"D:\\test folder\\\\\"", "Trailing path separator quoting failed.");
        Check(InstallEngine.Quote("a\"b") == "\"a\\\"b\"", "Quote escaping failed.");
        Check(InstallEngine.Quote("x; $() ' ü") == "\"x; $() ' ü\"", "Literal argument changed.");
        Check(!InstallEngine.Apply("Unknown", nested).Success, "Unknown operation accepted.");
        Check(!InstallEngine.Apply("Install", "relative").Success, "Relative game folder accepted.");
        bool rejected = false; try { InstallEngine.AssertWorkerResultPath(Path.Combine(root, "result.json")); } catch (ArgumentException) { rejected = true; }
        Check(rejected, "Unowned result path accepted.");
        Check(InstallEngine.Licenses().Contains("NeoMakesGames") && InstallEngine.Licenses().Contains("falorfrozen-cmd"), "Embedded license attribution missing.");
        NativeChecks(root, args[1]);
        Console.WriteLine("PASS " + passed + " installer detection, integrity and transaction guard checks."); return 0;
    }

    static void NativeChecks(string root, string package)
    {
        var json = new JavaScriptSerializer();
        var game = Path.Combine(root, @"Engine Steam\steamapps\common\Game");
        Directory.CreateDirectory(Path.Combine(game, @"Dungeons\Content\Paks"));
        Directory.CreateDirectory(Path.Combine(game, @"Dungeons\Binaries\Win64"));
        File.WriteAllText(Path.Combine(game, @"Dungeons\Content\Paks\global.utoc"), "fixture");
        File.WriteAllText(Path.Combine(game, @"Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe"), "fixture");
        File.WriteAllText(Path.Combine(root, @"Engine Steam\steamapps\appmanifest_1912410.acf"), "\"appid\" \"1912410\" \"buildid\" \"25754144\"");
        var engine = new NativeTransaction(game);
        var state = Path.Combine(game, @"ModLabBackups\ModLab.install.json");
        Rejected(() => engine.Apply("Restore", package), "No owned ModLab installation");
        var manifestPath = Path.Combine(package, "ModLab.manifest.json");
        var manifest = json.Deserialize<PackageManifest>(File.ReadAllText(manifestPath));
        var corrupt = Path.Combine(root, "Corrupt Runtime"); Directory.CreateDirectory(corrupt);
        foreach (var file in manifest.Files) File.Copy(Path.Combine(package, file.Name), Path.Combine(corrupt, file.Name));
        File.Copy(manifestPath, Path.Combine(corrupt, "ModLab.manifest.json"));
        File.AppendAllText(Path.Combine(corrupt, "QoLSuite_P.ucas"), "corruption");
        Rejected(() => engine.Apply("Install", corrupt), "File is missing or changed");
        Check(!Directory.Exists(Path.Combine(game, "ModLabBackups")), "Corrupt runtime mutated game before rejection.");
        // A second installer on another thread owns the same named lock.
        string lockHash;
        using (var hash = System.Security.Cryptography.SHA256.Create())
            lockHash = BitConverter.ToString(hash.ComputeHash(System.Text.Encoding.UTF8.GetBytes(game.ToLowerInvariant()))).Replace("-", "");
        using (var ready = new ManualResetEvent(false))
        using (var finish = new ManualResetEvent(false))
        {
            var holder = new Thread(() => {
                using (var mutex = new Mutex(false, @"Local\ModLabLoader-" + lockHash))
                { mutex.WaitOne(); ready.Set(); finish.WaitOne(); mutex.ReleaseMutex(); }
            });
            holder.Start(); ready.WaitOne();
            try { Rejected(() => engine.Apply("Install", package), "Another ModLab installer"); }
            finally { finish.Set(); holder.Join(); }
        }
        // An actual process with the game's name must stop installation.
        var blocker = Path.Combine(root, "Dungeons.exe"); File.Copy(Assembly.GetExecutingAssembly().Location, blocker);
        var signalName = @"Local\ModLab-test-game-" + Guid.NewGuid().ToString("N");
        using (var signal = new EventWaitHandle(false, EventResetMode.ManualReset, signalName))
        using (var process = Process.Start(new ProcessStartInfo(blocker, "--hold-game " + InstallEngine.Quote(signalName)) { UseShellExecute = false, CreateNoWindow = true }))
        {
            try { Rejected(() => engine.Apply("Install", package), "Close Minecraft Dungeons II"); }
            finally { signal.Set(); if (!process.WaitForExit(10000)) { process.Kill(); throw new Exception("Game fixture did not exit."); } }
        }
        Check(!File.Exists(state), "Rejected guard created ownership.");
        engine.Apply("Install", package);
        var stateText = File.ReadAllText(state);
        var record = json.Deserialize<InstallationRecord>(stateText);
        record.Originals = new[] { new OriginalFile { Path = Path.Combine(game, @"Dungeons\Content\Paks\~mods\Elsewhere\BlueprintLoader_P.pak"),
            Backup = Path.Combine(root, "unowned.pak"), SHA256 = new string('0', 64) } };
        File.WriteAllText(state, json.Serialize(record));
        Rejected(() => engine.Apply("Restore", package), "outside its owned directory");
        File.WriteAllText(state, stateText);
        engine.Apply("Restore", package);
        Check(!File.Exists(state), "Native guard checks did not restore fixture.");
    }
}
