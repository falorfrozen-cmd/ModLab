# Building

Clone this source repository before running the scripts below. Release ZIPs
contain the player package and documentation, not the build scripts or SDK.

## Installer from a released runtime package

This path needs Windows, PowerShell and the .NET Framework compiler included
with Windows. It does not require the game or NeoRune.

Extract the manual release ZIP, then run:

```powershell
pwsh -NoProfile -File tools/build_installer.ps1 -PackageDirectory 'D:\Downloads\ModLabLoader-Manual\ModLabLoader'
pwsh -NoProfile -File tests/run_installer_checks.ps1 -PackageDirectory 'D:\Downloads\ModLabLoader-Manual\ModLabLoader'
```

The build verifies each runtime file against its manifest, embeds the package
and transaction script into a single EXE, and generates the embedded package
hash. Output is in `dist/`. Only the installer and documented runtime artifacts
belong in the public release; internal build metadata and fixture executables
are not release files.

## Runtime from source

Required local inputs:

- .NET 10 SDK and NeoRune.Sdk 0.3.0 available to MSBuild.
- A NeoRune SDK root generated for game build **25754144**, containing its
  compiler, `ref/` bindings, helper `src/` and `tools/` directory.
- `retoc.exe`, `repak.exe`, `UAssetAPI.dll` and `Newtonsoft.Json.dll` in that
  SDK's tools directory, with their normal dependencies.
- A local Steam installation of the validated game build.

Use NeoRune's maintaining workflow to discover the game API and generate the
matching bindings. The generated SDK and game API are not shipped in this
repository. An older SDK's game bindings are not interchangeable with this
build just because the compiler version matches.

```powershell
pwsh -NoProfile -File tools/build_modlab_loader.ps1 -GameDirectory 'D:\SteamLibrary\steamapps\common\Minecraft Dungeons II' -SdkRoot 'D:\SDKs\NeoRune-build25754144'
```

The default SDK location is `tools/neorune-build25754144/`. The actor source
targets .NET 8; the bootstrap adapter targets .NET 10. Supply the asset key via
`MODLAB_GAME_AES_KEY` or `-AesKey`, or allow the script to retrieve the mod kit's
public key. No source or binary is executed from that key download.

The script extracts the original R1 feature locally, verifies its fingerprint,
preserves its native actions, appends our component request, round-trips the
result and verifies the completed IoStore package before publishing it to
`mods/ModLabLoader/bin/NeoRune/Pak/`. It does **not** install into the game.
Rebuilding may produce different binary hashes due to generated asset metadata.
Validate your rebuild in the game before distributing it. The first release
uses the exact runtime triplet recorded in RUNTIME-VALIDATION.md.

```powershell
pwsh -NoProfile -File tools/build_installer.ps1 -PackageDirectory 'mods\ModLabLoader\bin\NeoRune\Pak'
```

## Checks

`tests/run_installer_checks.ps1` runs the core transaction fixtures, the compiled
EXE's actual embedded-payload worker, and C# library detection/argument checks.
Fixtures stay outside the real game directory. Close the game before running
the installation checks because the production engine's game-running guard is
retained in the tests.

Native game test evidence from ModLab's isolated-save runner is documented in
[RUNTIME-VALIDATION.md](RUNTIME-VALIDATION.md). That runner exercises the separate
ModLab project and is not distributed in this loader-only repository. Probe
mod source is included under `tests/ModLabLoaderProbe` for mod developers.
