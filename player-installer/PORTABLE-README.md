# ModLab portable Setup

This is a release candidate. Antivirus and distribution review must complete
before publication. It contains the same eight runtime files as the existing
ModLab package; only the installation application and packaging have changed.

1. Close Minecraft Dungeons II.
2. Extract the complete ZIP. Keep `ModLab.exe` beside its `Package` folder.
3. Open `ModLab.exe`. For a protected Steam game folder, use **Run as administrator**.
4. Select your game folder containing `Dungeons`, choose **Install / Update
   ModLab**, and click **Apply**.
5. Start the game through Steam and press **F10**.

Steam libraries are detected automatically. Browse supports custom locations.
Supports Steam build **25754144**, game **1.1.2.0**, Windows x64 with .NET Framework 4.8.
There is no PowerShell script, download, background service, executable unpacking,
or separately launched installation worker. The application closes after installation.

To update or remove, open the same application and select the corresponding
operation. Keep the game's `ModLabBackups` folder. The original installation
is restored on removal, including former ModLab or Blueprint Loader files.
Changed ownership records, altered package files, unsupported game builds and
conflicting loaders are rejected. The installer does not edit character saves.

The application is unsigned. Check `SHA256SUMS.txt` against the published download.
Running only the EXE from inside the ZIP is unsupported: extract all files first.
