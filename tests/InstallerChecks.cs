using System;
using System.IO;
using System.Linq;
using ModLabLoader.Setup;

public static class InstallerChecks
{
    static int passed;
    static void Check(bool value, string name) { if (!value) throw new Exception(name); passed++; }
    public static int Main(string[] args)
    {
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
        Check(!SteamDiscovery.CompleteModLabInstalled(nested), "Uninstalled ModLab Complete detected.");
        Directory.CreateDirectory(Path.Combine(nested, "ModLabBackups"));
        var completeRecord = Path.Combine(nested, @"ModLabBackups\ModLab.install.json");
        File.WriteAllText(completeRecord, "{\"Profile\":\"ModLab\"}");
        Check(SteamDiscovery.CompleteModLabInstalled(nested), "Combined installation not detected.");
        var installGuard = InstallEngine.Apply("Install", nested);
        Check(!installGuard.Success && installGuard.Message.Contains("ModLab Complete"), "Standalone installer did not direct combined installation to the correct Setup.");
        var restoreGuard = InstallEngine.Apply("Restore", nested);
        Check(!restoreGuard.Success && restoreGuard.Message.Contains("ModLab Complete"), "Standalone removal bypassed combined ownership.");
        Check(File.ReadAllText(completeRecord) == "{\"Profile\":\"ModLab\"}", "Standalone guard changed combined ownership.");
        Console.WriteLine("PASS " + passed + " installer detection/argument checks."); return 0;
    }
}
