# Xbox / Microsoft Store / PC Game Pass preflight

**Status: discovery and diagnostic preparation only. Xbox installation and
gameplay compatibility are not yet enabled or verified.** The existing player
installers still require Steam build 25754144. No previously scanned installer
or runtime package has been rebuilt for this preflight.

Microsoft documents modern MSIXVC PC games as accessible flat files under
`[drive]:\XboxGames`. It also documents `MicrosoftGame.config` as the source of
package identity/version and executable declarations. These facts do not prove
that a specific Xbox build supports the existing ModLab runtime packages.

- [Microsoft PC packaging documentation](https://learn.microsoft.com/en-us/xbox/gdk/docs/features/common/packaging/overviews/packaging-getting-started-for-pc?view=gdk-2604)
- [MicrosoftGame.config overview](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/game-config/microsoftgameconfig-overview?view=gdk-2604)

## Collect a report on a volunteer's PC

Download and inspect `tools/get_xbox_installation_report.ps1` from this repository.
This is a developer diagnostic script, separate from the player installer.
From PowerShell, in the directory containing the downloaded script:

```powershell
.\get_xbox_installation_report.ps1 -GameDirectory 'D:\XboxGames\YOUR ACTUAL GAME FOLDER'
```

Use the folder shown by the Xbox app's game management/file-browsing feature.
The folder itself or its `Content` subfolder can be selected. Do not assume the
game directory has the same display name on every PC. Automatic discovery is
also available by running the script without `GameDirectory`; it checks one
level of `XboxGames` on ready local fixed drives. For a custom Xbox library,
pass `-XboxLibraryRoots 'D:\My actual library'` or select the game explicitly.
The script does not parse the undocumented `.GamingRoot` file format.

The script prints the location of a new JSON report in the temporary directory.
Review that JSON before choosing to share it. It contains relative game paths,
selected package identity/version/executable declarations, sizes and SHA-256
hashes of the shipping executable(s) and `global.utoc`. It does not upload
anything or include game bytes, account identifiers, saves, or absolute game
locations by default. `-IncludePaths` explicitly opts into absolute content
locations. An existing output file is never overwritten.

It does not install a mod, start or close the game, probe write permissions,
change execution policy/permissions, or access protected `WindowsApps` or
junctions. If local policy prevents running the downloaded script, use the
manual evidence option below; changing security settings is not required.

Candidate layouts include `Dungeons` and `Dun`, beneath the selected folder
or its `Content` child, with `Win64`/`WinGDK` shipping executables. These are
structural candidates, not confirmed Minecraft Dungeons II identities. A
different layout can be investigated from the manual folder information.

## Manual evidence option

A volunteer can instead provide the version shown in the game menu, the
relative paths/names of the game EXE and `global.utoc`, and the `Identity`
Name/Version plus executable Name entries from `MicrosoftGame.config`.
Do not ask for the entire game, saves, account credentials, or a purchase.
EXE version strings may be generic: the locally installed Steam EXE reports
`UE5-CL-0`, so the preflight does not treat them as a compatibility decision.

## Enabling support after evidence is received

1. Identify the actual Store package and normalize its content root. Validate
   package/version and file-layout details independently of Steam metadata.
2. Add a separate Xbox compatibility profile. Preserve the existing Steam
   build restriction, package hash checks, backup/ownership records, conflict
   detection, rollback and restoration. A missing Steam manifest must not
   become permission to install on an arbitrary game.
3. Test the actual compiled installer on disposable Xbox-like fixtures:
   fresh install, update, removal, previous-loader restoration, closed-game
   guard, tampered package/state and partial failure.
4. Have a volunteer run the approved candidate on their real Xbox/Game Pass
   installation: loader starts, F10 works, a representative gameplay feature
   works, restart preserves settings, and removal restores the baseline.
5. Advertise support only for the real platform/build combinations verified.
   AV classification and Nexus approval remain separate release requirements.

## Checks completed locally

`tests/check_xbox_preflight.ps1` passed on PowerShell 7.6.5 and Windows
PowerShell 5.1. It covers custom libraries, spaces/Unicode/dollar characters,
Content selection, Dungeons/Win64 and Dun/WinGDK layouts, deduplication,
unrelated folders, invalid external-entity XML, absence of absolute game paths,
occupied/game-directory output rejection, and unchanged source files. These
are artificial fixtures and establish preflight behavior only. A read-only
report was also collected from the actual Steam installation; it cannot
substitute for a real Xbox runtime test.

## Suggested response to the request

> Thanks for the detailed request. The modern XboxGames flat-file layout looks
> feasible to support, and you do not need to send us the game itself. We have
> prepared a read-only preflight script to collect the package identity, file
> layout and file fingerprints. Our current installer is still Steam-only:
> matching folders alone does not confirm runtime compatibility. If you would
> like to help test, please share the preflight JSON and the version shown in
> your game menu. We can then prepare a platform-specific test build and verify
> installation, gameplay and removal with you before advertising support.
