# Building the portable Setup candidate

This is an installer-only alternative to the standard Inno Setup wrapper.
It uses the same `NativeTransaction.cs` and `SteamDiscovery.cs`; the game mod
is not rebuilt. No archive or helper EXE is embedded in the application.

1. Select the previously validated eight-file ModLab runtime package containing
   `ModLab.manifest.json`. Do not use a diagnostic or self-test game package.
2. Run `tools/build_portable_installer.ps1 -PackageDirectory <package>
   -Version 0.1.0-alpha.7 -OutputDirectory <new isolated directory>`.
   The output directory must not exist. Windows' C# compiler must have a valid
   Microsoft Authenticode signature. The builder validates the manifest schema,
   target game build, exact file names, destinations, sizes and hashes.
3. Run `tests/check_portable_setup.ps1 -DistributionZip <complete ZIP>
   -ExpectedExecutableSHA256 <SHA-256 from the build record>
   -PreviousSetupPath <released alpha.2 EXE>`.
   This tests the actual application extracted from the distribution ZIP,
   including ownership migration, restoration, rollback and integrity rejection.
4. Record separate completed VirusTotal reports for `ModLab/ModLab.exe` and
   the complete ZIP. An archive scan is not a substitute for the EXE report.
5. Verify the GUI on the supported Windows environment and obtain actual
   distribution approval before promoting a candidate as a recommended download.

Outputs include `ModLab/ModLab.exe`, its external `Package` directory, license
notices, the complete distribution ZIP, `portable-installer-build.json` and
`SHA256SUMS.txt`. Runtime files must remain beside the EXE during installation.
They are copied unchanged; the exact manifest SHA-256 is compiled into the EXE.

The application runs with the invoking user's permissions. Protected Steam
locations may require **Run as administrator**. It does not spawn an elevated
helper. Its normal English interface selects a Steam-detected or manually chosen
game folder, then performs Install/Update or Remove/Restore.

`--worker Install|Restore <game folder> <new temporary result.json>` is a
compatibility command mode for compiled regression tests, executed within the
same application. It does not start a separate worker process. Result paths
must be new files in existing temporary directories without reparse points.

Current candidate is unsigned. Changing the package architecture is an
engineering comparison, not a guarantee of antivirus acceptance. Preserve
uploaded bytes and reports; do not alter hashes or disable protections to
change a scan result.
