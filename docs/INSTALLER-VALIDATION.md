# Installer validation — 2026-10-09

The release EXE embeds the same three runtime files used in the successful
native game tests. It changes packaging and installation, not loader bytecode.

The actual compiled EXE worker, including embedded ZIP extraction and Windows
PowerShell **5.1**, passed install, update and restore in a disposable Steam tree
with spaces, Unicode and a literal `$` in its path. Restored original package
hashes matched. An unsupported Steam build was rejected without changing the
original packages.
Installation, update and removal also passed in a clean fixture with no previous
loader. Removal did not enable a loader that the installer had never backed up.

The core transaction fixtures passed:

- Install and update with preservation of original loader backups.
- Restore of every original package and preservation of an unrelated file.
- Rejection of a damaged runtime package, an unsupported build and duplicated
  installation-state records.
- Rollback after a locked original package forces a move failure, including
  restoration of an original package that had already moved.
- Discovery and restoration of a known loader placed in a custom mod folder.

Fifteen C# checks passed for secondary Steam libraries, modern and legacy VDF,
custom install names, duplicate library roots, app identity, path traversal,
Windows argument escaping, invalid worker result paths and embedded licenses. Fixtures use source
metadata and empty game placeholders; they do not claim game-version validation.

The installer UI was rendered and checked for readable controls and navigation.
The actual worker was tested without UAC in a writable fixture. The Windows UAC
consent prompt and use under a different administrator account have not been
automated; cancellation returns without starting installation. The GUI starts
without administrator privileges and elevates its hidden installation worker.

Tests initially found an inherited PowerShell 7 module-path issue in the Windows
5.1 child; the child now selects Windows' own module directory and the compiled
EXE scenario was rerun successfully. A long detection-fixture path exceeded
the older framework's path handling; the test uses a normal-length temp fixture.
Very long Steam installation paths have not been validated.

No fixture failure is counted as passing. No player save is read or modified
by the installer. The EXE is unsigned; the release provides SHA256 hashes and a
manual package alternative.
