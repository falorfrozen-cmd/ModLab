# ModLab Loader 0.1.0-alpha.2

Installer-only update; the native loader runtime is unchanged.

**ModLab players should use the [complete ModLab installer](https://github.com/falorfrozen-cmd/ModLab/releases/tag/modlab-v0.1.0-alpha.1), which includes both gameplay mods and the loader.**

The standalone installer now detects the combined ModLab installation record,
disables standalone install/removal and points to the correct Setup. It no
longer mistakes combined ownership for an unrecorded manual loader installation.
The script also refuses changes under combined ownership. No manual file
deletion or duplicate ownership record is needed.

The window labels itself as standalone, includes a complete-ModLab download
link and has more space for status text. Existing standalone installation,
update and restoration behavior remains available for other Blueprint mods.

Downloads are `ModLabLoader-Setup-0.1.0-alpha.2.exe`,
`ModLabLoader-Manual-0.1.0-alpha.2.zip` and
`ModLabLoader-Nexus-0.1.0-alpha.2.zip`, plus `SHA256SUMS.txt`.

## Previous release: 0.1.0-alpha.1

First experimental release of an independent Blueprint mod loader for
Minecraft Dungeons II. Validated target: **Steam build 25754144 / game 1.1.2.0**.

## Downloads

- `ModLabLoader-Setup-0.1.0-alpha.1.exe`: portable English Windows installer.
  Detects Steam libraries, installs/updates the verified runtime, and provides
  **Remove / Restore** for the loader it backed up.
- `ModLabLoader-Manual-0.1.0-alpha.1.zip`: runtime package for manual installation.
- `ModLabLoader-Nexus-0.1.0-alpha.1.zip`: Setup, the manual package and release
  documentation together for testers and Nexus distribution.
- `SHA256SUMS.txt`: SHA256 hashes for those downloads.

The loader discovers conventional ModActor entry points and has no recurring
scan or per-frame loader tick. Runtime is approximately 40 KiB. The installer
does not include ModLab gameplay mods, developer SDKs, diagnostic probe mods,
another author's loader, services or save files.

## Validation

Native menu/character/world startup, six F10 input-recovery cycles, Dungeon
movement, Rift travel/return, two independently packaged probe mods and mod
skipping passed. Successful native runs exited with code 0. A final normal-mode
test confirmed that no loader log save was created.

Compiled Setup install/update/restore and unsupported-build rejection passed
using its real embedded package and Windows PowerShell 5.1. Transaction checks
include corrupted-package rejection, custom-folder loader discovery and rollback
after a partial move failure. See the repository's validation documents.

## Before testing

Close the game before installing or removing. Use **one loader at a time**.
Other game builds, Xbox/Game Pass and multiplayer are unvalidated. Shared mod
settings/popup APIs, dependency ordering and crash quarantine are not present.
Mods requiring those APIs should keep their original loader.

Setup is unsigned and Windows may display an unknown-publisher warning. It uses
Windows' built-in .NET Framework 4.8 and PowerShell 5.1; a .NET SDK, Python and
NeoRune are not required by players. Very long installation paths and UAC under
a different administrator account have not been validated. This alpha release
does not claim to fix the wider game's intermittent shutdown access violation.
