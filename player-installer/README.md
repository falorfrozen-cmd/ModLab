# Complete ModLab installer source

This directory contains the full source of the **alpha.5 standard player
installer**, including its C# transaction engine. Alpha.5 fixes the Temp path
alias compatibility issue found by the clean Windows runner. One EXE installs the gameplay
suite and integrated loader together.

The original standalone loader source remains in `installer/`. The alpha.3
custom WinForms wrapper is retained here for comparison; its scan did not
resolve the original detections. Alpha.4 uses `ModLab.iss`, `NativeWorker.cs`,
`SteamDiscovery.cs` and `NativeTransaction.cs` instead.

The gameplay suite source is maintained separately. Its already released eight
runtime files are build inputs. Rebuilding Setup from them needs no game SDK.

## Runtime behavior

- Uses a standard Inno Setup 7.1.0 wizard with an inspectable, small C# worker.
- Discovers Steam libraries, offers Browse, and supports Install/Update or
  Remove/Restore in the same EXE.
- Verifies a compiled manifest SHA-256 and every runtime hash and file size.
- Installs exactly eight runtime files under the selected game's `~mods`.
- Backs up existing ModLab and conflicting loader files outside mounted Paks.
- Preserves the original baseline across updates and rolls back failed moves.
  Existing alpha.2 ownership records remain compatible.
- Rejects concurrent installers, running game processes, changed owned files,
  invalid destinations, junctions and symbolic links.
- Requests normal Windows UAC permission for protected Steam game folders.
- Executes file operations in C#. No PowerShell execution, execution-policy
  changes, downloader, background service or save access.
- Uses stock installer compression. No custom obfuscation, anti-debug check,
  artificial delay or antivirus exclusion is added by ModLab.

The EXE is unsigned. [Antivirus scan observations](SCAN-RESULTS.md) are recorded separately from
functional tests. No scan guarantees safety. The separately documented game
shutdown issue is not resolved by installer changes.

## Build on Windows

Requires .NET Framework 4.8 and the C# compiler shipped with Windows, plus the
[official Inno Setup 7.1.0 x64 compiler](https://jrsoftware.org/isdl.php).

1. Obtain the approved **ModLab 0.1.0-alpha.2 - Complete Manual Package** from
   [Nexus](https://www.nexusmods.com/minecraftdungeons2/mods/147?tab=files).
2. Copy the eight runtime files from `Dungeons/Content/Paks/~mods/ModLabLoader`
   and `QoLSuite` in that ZIP into one staging folder with their filenames.
   Copy `ModLab-runtime-manifest.json` into the staging folder as
   `ModLab.manifest.json`. All eight manifest hashes must match.
3. Run from the repository root:

   ```powershell
   ./tools/build_standard_installer.ps1 -PackageDirectory 'C:\ModLab-runtime' -InnoCompiler 'C:\Program Files\Inno Setup 7\ISCC.exe' -Version 0.1.0-alpha.5
   ./tests/check_standard_worker.ps1 -BuildMetadata './dist/player/standard-installer-build.json'
   ./tests/check_modlab_setup.ps1 -SetupPath './dist/player/ModLab-Setup-0.1.0-alpha.5.exe' -PackageDirectory 'C:\ModLab-runtime' -StandardSetup
   ```

The EXE is written to `dist/player/ModLab-Setup-0.1.0-alpha.5.exe`. Build
metadata, worker hash and generated manifest binding are recorded in
`dist/player/standard-installer-build.json`. Compiler timestamps may differ;
compare source and extracted runtime hashes rather than expecting byte-identical
EXEs across separate builds.

The build requires valid Microsoft and Pyrsys compiler signatures before
invoking those tools. It records their hashes, certificate identities and the
manifest hash, and preserves a versioned
`standard-installer-build-<version>.json` record. Existing EXEs or versioned
records cannot be overwritten. An exclusive lock rejects simultaneous builds
of the same version/output. For a local rebuild, use
`-OutputDirectory 'C:\ModLab-rebuild'` and use that directory's metadata in the
checks above. Preserve uploaded release bytes and their scan identity.
Run `./tests/check_installer_build_guard.ps1 -InnoCompiler '<ISCC.exe path>'`
to verify unsigned/wrong-publisher compiler rejection and existing-output
preservation. These controls do not clear antivirus detections.

The tests use temporary fixtures with Inno's `/CURRENTUSER` option and never
install to the protected real game folder. The final EXE was additionally
checked for migration from the previously released alpha.2 EXE:

```powershell
./tests/check_modlab_setup.ps1 -SetupPath 'C:\ModLab-Setup-0.1.0-alpha.5.exe' -PackageDirectory 'C:\ModLab-runtime' -PreviousSetupPath 'C:\ModLab-Setup-0.1.0-alpha.2.exe' -StandardSetup
```

The native engine's detection, integrity, concurrency and running-game checks
can also be exercised through `tests/run_player_installer_checks.ps1`. This
builds the retained alpha.3 test wrapper; it does not publish that candidate.
See [validation](VALIDATION.md). Build/test PowerShell scripts are development
tools and are not included or executed in the player's installation.

## Licensing

The installer source is MIT licensed under [LICENSE](LICENSE). Inno Setup and
the embedded runtime retain their component licenses and
[third-party notices](THIRD-PARTY-NOTICES.md). This directory does not relicense
the gameplay suite or original game content.
