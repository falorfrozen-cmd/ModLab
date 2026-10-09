# ModLab alpha validation

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
files, a manifest, its transaction script and license notices.

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
