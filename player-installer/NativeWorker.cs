using System;
using System.IO;
using System.Reflection;
using System.Text;

namespace ModLab.Setup
{
    // A small, inspectable helper for the standard installer. Contains no
    // runtime archive, UI assets, interpreter or downloaded dependencies.
    public static class NativeWorker
    {
        static void WriteNew(string path, string text)
        {
            using (var stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            using (var writer = new StreamWriter(stream, new UTF8Encoding(false))) writer.Write(text);
        }

        public static int Main(string[] args)
        {
            AppContext.SetSwitch("Switch.System.IO.UseLegacyPathHandling", false);
            AppContext.SetSwitch("Switch.System.IO.BlockLongPaths", false);
            var directory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            var resultPath = Path.Combine(directory, "ModLab-result.txt");
            bool canWrite = false;
            try
            {
                // The installer extracts the helper and data into its private Temp.
                // Command-line use cannot select an arbitrary result destination.
                if (!directory.StartsWith(Path.GetFullPath(Path.GetTempPath()).TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase) ||
                    (File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0)
                    throw new ArgumentException("The installer helper must run from its temporary package directory.");
                canWrite = true;
                if (args.Length == 1 && args[0] == "--discover")
                {
                    WriteNew(Path.Combine(directory, "ModLab-games.txt"), String.Join("\r\n", SteamDiscovery.Discover()));
                    return 0;
                }
                if (args.Length != 2 || (args[0] != "Install" && args[0] != "Restore"))
                    throw new ArgumentException("Expected Install or Restore and an absolute game folder.");
                if (File.Exists(resultPath) || Directory.Exists(resultPath))
                    throw new IOException("The installer result destination is already occupied.");
                NativeTransaction.AssertHash(Path.Combine(directory, "ModLab.manifest.json"), BuildIdentity.ManifestSha256);
                var details = new NativeTransaction(args[1]).Apply(args[0], directory);
                WriteNew(resultPath, "OK\r\n" + details);
                return 0;
            }
            catch (Exception error)
            {
                if (canWrite)
                    try { WriteNew(resultPath, "ERROR\r\n" + error.Message + "\r\n" + error); } catch (IOException) { } catch (UnauthorizedAccessException) { }
                return 1;
            }
        }
    }
}
