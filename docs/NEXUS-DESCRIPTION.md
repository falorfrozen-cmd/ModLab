# ModLab Loader — Experimental

A lightweight, independent Blueprint mod loader for Minecraft Dungeons II.
Approximately 40 KiB of runtime packages, one startup pass per world, and a
reversible Windows installer.

## Compatibility

This first experimental release is validated on **Steam build 25754144, game
1.1.2.0, Unreal Engine 5.6.1**. Xbox/Game Pass, other builds and multiplayer have
not been validated. Setup rejects unsupported Steam builds.

## Files

- **Windows Setup:** run the EXE, select the game folder and click Install /
  Update. Steam libraries on other drives are detected; manual browsing is
  supported. Windows may request administrator permission. Run Setup again
  and select Remove / Restore to undo installation.
- **Manual package:** copy the ModLabLoader folder into
  Dungeons/Content/Paks/~mods while the game is closed. Disable every other
  loader by moving its package files outside Paks first.
- **SHA256SUMS.txt:** hashes for the release downloads. Setup is unsigned.

Setup backs up known conflicting Blueprint Loader / BetterBlueprintLoader
packages outside mounted Paks and preserves character saves and other mods.
Backups remain after removal. Setup is a portable tool, not a background
service or a Windows Apps entry.

## Mod support

Loads conventional /Game/Mods/<ModId>/ModActor.ModActor_C entry points.
No per-frame loader tick, recurring scan, DLL injection or desktop process
runs during gameplay. Players do not install NeoRune, Python or a .NET SDK.
Windows Setup uses the PowerShell 5.1 and .NET Framework 4.8 supplied with
current Windows 10/11.

Use one loader at a time. Mods depending on another loader's shared settings,
popup or other ecosystem APIs need that loader instead. This release does not
implement those APIs, dependency ordering, automatic crash quarantine or native
DLL mod loading. It makes no FPS or speed comparison claims.

This is the loader only. ModLab gameplay features and its F10 interface are
separate mods. Normal startup adds no permanent loader watermark.

## Support and source

Source, validation notes and downloads:
https://github.com/falorfrozen-cmd/Minecraft-Dungeons-II-ModLab-Loader

Report the game build, platform, loader version, installed mods and steps to
reproduce a problem. Optional startup logging: -ModLabLoaderDiagnostics.
Skip a mod: -ModLabLoaderSkip=ExampleA,ExampleB (case-sensitive IDs).

Independent implementation; no Blueprint Loader package or source is bundled.
Our source is MIT-licensed; NeoRune's MIT helper notice is included in the files.
Unofficial fan project, not affiliated with Mojang, Microsoft or Epic Games.
