# ModLab Loader validation — 2026-10-09

Local target: Steam build 25754144 / game 1.1.2.0 / UE 5.6.1.
Every native run uses a disposable copy of the save directory. The original
directory is preserved outside the active slot path and restored with all hashes
verified. Blueprint Loader's three package files are disabled during independent
loader runs. The runner restores the normal ModLab package after each run.

| Native evidence directory | Result |
| --- | --- |
| `diagnostics/native-check-20261009-195355` | Initial bootstrap: menu, existing character, Overworld, native exit. Exit 0, no crash report. This early prototype still had an optional fixed ModLab entry; subsequent builds removed it. |
| `diagnostics/native-check-20261009-200200` | Six real F10 cycles: saved settings, F10/Esc/button closure, browser focus and capture restoration, actual Dungeon movement. Exit 0. |
| `diagnostics/native-check-20261009-200831` | Generic discovery with no fixed ModLab entry. ModLab plus two separately packaged probe mods, identical class names in different packages. Each probe has exactly one actor in menu and Overworld. Real Rift travel and return pass. Exit 0. |
| `diagnostics/native-check-20261009-203357` | Skip option: ModLab and probe A start in both worlds; probe B never starts. Native character flow and shutdown pass, exit 0. Loader proof passes. |
| `diagnostics/native-check-20261009-204057` | Final package with loader diagnostics disabled. Six F10/save/close/native Dungeon movement cycles pass. No loader log save is created. Exit 0, no crash report. |

The skip test initially exposed a command-line parsing bug; the parameter's
required `=` suffix was corrected and the scenario rerun. No failed run is
counted as passing. Build-time errors encountered while setting up the .NET 10
asset adapter did not count as game tests.

The final tested package contains only three runtime files (41,099 bytes total):

| File | SHA256 |
| --- | --- |
| `ModLabLoader_P.pak` | `50EE4A3D89B299CECA062559A984FFDA0D4B8846F51EE46546B8EE66D96420E9` |
| `ModLabLoader_P.ucas` | `420974C422D2BA9EA988AD9DC7FB1107D7A8BD1BD5A9A02BE819D0C7E37285F0` |
| `ModLabLoader_P.utoc` | `E67B96619EAFF688EC79ECE9FE2D9867800B9E1848C0DF52E0CA550FCD215BD1` |

The asset adapter verifies the original R1 header fingerprint, its expected
action-array layout, the untouched native action payloads and native scan settings.
It round-trips the appended component request through UAssetAPI. retoc verifies
the completed IoStore container. Package publication is staged: a failed build
does not replace the previous verified triplet.

`tests/check_modlab_loader_install.ps1` validates installation, upgrade, original
loader restoration, preservation of unrelated files and rejection of a damaged
package before mutation in a disposable game-tree fixture. Original packages
are archived outside mounted Paks. Runtime save files are not touched by the
installer. The actual loader binary is used in this fixture, not a mock package.

The existing regression suites also pass: 378 C# checks and 56 Python tests.

## Limits

This is experimental evidence on one game build, not a claim of universal
compatibility. No Xbox/Game Pass or multiplayer validation has been performed.
Loader 2.x settings integration and automatic crash quarantine are not present.
The wider game's previously observed intermittent 0xC0000005 shutdown fault has
not been declared fixed merely because these runs exited cleanly.
