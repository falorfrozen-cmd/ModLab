# ModLab alpha validation

## Alpha.4 standard installer validation, 2026-10-10

The same C# transaction engine is wrapped by standard Inno Setup 7.1.0.
The worker contains no embedded archive or gameplay assets. The standard
installer stores the eight unchanged alpha.2 runtime files as normal file
entries and binds its manifest with a compiled SHA-256. All installation
operations still run in C#; no PowerShell script is executed.

The final compiled standard EXE passed the complete install/update/remove,
legacy loader adoption, original alpha.2 ownership migration, locked-file
rollback, altered ownership and unsupported-build scenarios in temporary
fixtures. Fixture runs use Inno's supported `/CURRENTUSER` mode, so tests do
not require UAC permission or touch the actual protected Steam installation.
Normal player startup requests UAC permission for protected game folders.

Additional checks ran the actual compiled worker from a temporary extraction:
an occupied result destination and changed manifest were rejected before
any game mutation. UTF-8 result and discovery files are used by the wizard.
The eight runtime SHA-256 values remain identical to alpha.2.

Antivirus acceptance is tracked separately from functional tests. Alpha.3's
C#-only custom EXE still produced the same 8/71 detections as alpha.2, so
removing PowerShell did not establish the cause. The final alpha.4 EXE showed
1/71 (SecureAge: Malicious); its distribution ZIP separately showed 1/68
(Zillya: Backdoor.Agent.Win32.101941). Nexus file 397 remains quarantined.
No vendor rule has been disclosed and no safety guarantee is claimed. The
approved manual package remains primary. The public installer source includes
the exact artifact hashes and report links in `player-installer/SCAN-RESULTS.md`.

## Alpha.3 installer-only validation, 2026-10-10

The eight installed runtime files are byte-identical to the alpha.2 player
package. The installer backend was ported to managed C#; the distributed EXE
contains no PowerShell script and does not launch an interpreter or change
execution policy. Developer rendering is excluded from the player build.

The compiled EXE passed fresh install, update, removal, exact restoration of
previous Blueprint Loader files, standalone loader adoption, and rollback
after partially moving locked files. A second run installed using the original
alpha.2 EXE, then updated and removed with alpha.3; ownership format and restore
baseline remained compatible. Unrelated mod and save sentinels remained unchanged.

Twenty-three detection, argument, license, integrity and guard checks passed,
including a corrupt runtime, an unowned backup path, another installer holding
the named lock and an actual process named Dungeons. These exercise the new C#
backend directly. Unsupported builds and altered installed destinations were
also rejected by the compiled Setup EXE. Paths include Unicode, spaces and `$`.

This verifies installer behavior, not antivirus acceptance. The original
alpha.2 EXE's VirusTotal report showed 8/71 detections; its distribution ZIP
showed 2/66. No exact vendor rule or malicious code was identified by those
labels. The alpha.3 EXE's separate scan also showed 8/71 detections. Removing
PowerShell alone did not clear them. The standard alpha.4 wrapper is the
subsequent candidate, not a claim that the alpha.3 detection was resolved.

## Earlier gameplay and alpha.2 validation

Validated on Windows x64 for Steam build 25754144 / game 1.1.2.0, 2026-10-09.

Alpha.2 changes presentation and documentation. The eight gameplay/runtime
files are unchanged from alpha.1. Its compiled ModLab Setup was retested for
fresh installation, updating, adoption, removal, rollback and invalid input.

## Player build

QoLSuite was rebuilt with `QoLRunSelfTests=false` and `NeoRuneInstall=false`
into a separate output directory: zero compiler warnings or errors. Its
project excludes diagnostic test scenarios from normal player builds.
The loader triplet is the same SHA-256-verified runtime used in the independent
loader's native validation. The complete installer embeds exactly eight runtime
files, a manifest, its original transaction script and license notices.

## Compiled installer

The actual Setup EXE, including its embedded runtime payload, was exercised
through its hidden worker with Windows PowerShell 5.1. Checks passed for:

- Fifteen detection, argument quoting and license checks.
- Fresh install, update and complete removal without a previous loader.
- Existing Blueprint Loader in a custom mods subdirectory; exact restoration.
- Existing standalone ModLab Loader plus all five prior ModLab files;
  adoption, update and exact restoration of all nine baseline files, including
  the standalone loader ownership record and its untouched backup archives.
- Locked late runtime files causing partial moves; rollback restored exact
  pre-operation runtime hashes and ownership state.
- Preserving the original restore baseline across updates.
- Rejecting an unsupported Steam build, altered ownership destination and
  corrupted runtime download before changes.
- Paths with spaces, Unicode and a literal dollar sign.
- Preserving unrelated mod and save-sentinel files.
- Refusing package changes while the game is running.

Setup's rendered English window was visually checked for clipping.

The compiled EXE was also installed and updated in the actual Steam game
folder. All eight installed runtime hashes matched the player manifest. Its
nine existing baseline files, including the previous standalone loader record,
were adopted as backups. All character/settings save hashes remained unchanged.

## Native game check

The native diagnostic variant of the same gameplay sources was run with the
independent loader in quiet mode. It entered a Dungeon and passed six actual
F10 open/save/close cycles with different cursor and mouse-capture states.
Browser focus was released and native character movement succeeded after each
close. No loader diagnostic save was generated. The runner restored the
original save directory and verified its hashes.

The latest run exited with **0xC0000005 after the gameplay checks passed**.
This is not counted as a clean overall native test pass. Earlier independent
loader runs exited cleanly; the wider shutdown issue has also occurred in
package-free controls. This release does not claim to resolve it.

These checks do not establish compatibility with other game builds, launchers
or multiplayer, nor certify every gameplay feature in this alpha.
