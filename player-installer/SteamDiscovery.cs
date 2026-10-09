using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace ModLab.Setup
{
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
    }

}
