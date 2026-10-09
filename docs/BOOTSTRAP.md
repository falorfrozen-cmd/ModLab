# ModLab bootstrap — developer reference

The bootstrap is included in the single ModLab player installer. Players should
follow the [ModLab page](https://github.com/falorfrozen-cmd/ModLab). Internal asset and package identifiers
retain `ModLabLoader` for compatibility with installed packages.

## What it does

- Loads conventional `/Game/Mods/<ModId>/ModActor.ModActor_C` entry points.
- Discovers mods generically; ModLab is not hard-coded into the loader.
- Checks for existing actors to avoid duplicate startup in a world.
- Performs one bounded startup pass per world, then stops the loading queue.
- Has no recurring scan, per-frame loader tick, DLL injection or desktop process
  during gameplay. The runtime package is approximately **40 KiB**.
- Supports an optional diagnostic trace and a command-line skip list.

The standalone package contains **the loader only**. The complete ModLab
installer linked above bundles it with the F10 interface and gameplay suite. The loader
does not display a permanent startup watermark. Confirm it through a loaded
mod, or enable diagnostics to check the startup trace.

## Scope and limitations

This is an independent implementation, not a renamed or bundled Blueprint
Loader. It is not a complete replacement for every mod-loading ecosystem API:
Blueprint Loader's shared settings menu and popup API are not implemented.
Dependency/start-order metadata and automatic crash quarantine are also absent.
Mods relying on those APIs need their original loader. Native DLL mods are not
supported. No performance improvement over other loaders is claimed.

The bootstrap overlays `/R1/R1` through the game's Game Features system while
preserving the original action payloads and scan settings. Original game
containers are not edited. Another mod overriding the same asset can conflict.
The build adapter checks the original asset fingerprint and rejects unfamiliar
layouts; new game updates require inspection and validation.

## Troubleshooting

Add `-ModLabLoaderDiagnostics` in Steam's launch options to record startup in
`Dungeons2/Saved/SaveGames/NeoRune_ModLabLoader.sav`. Normal play produces no
loader log save. This trace does not catch arbitrary native crashes in mods.

Use `-ModLabLoaderSkip=ExampleA,ExampleB` to skip specific mod IDs. IDs are
case-sensitive and refer to the asset folder under `/Game/Mods`. Restart the
game after changing packages or launch options.

For an issue, include the game build, platform, loader version, other installed
mods and the steps to reproduce it. Do not upload character saves unless you
intend to share them.

## Development

See [BUILDING.md](BUILDING.md), [runtime validation](RUNTIME-VALIDATION.md)
and [installer validation](INSTALLER-VALIDATION.md). The installer can be
built independently of the mod compiler from a verified runtime package.

Our source is MIT-licensed. NeoRune helper attribution is retained in
[`NeoRune-LICENSE.txt`](../mods/ModLabLoader/Branding/NeoRune-LICENSE.txt).
See [third-party notices](../THIRD-PARTY-NOTICES.md).

Unofficial fan project. Not affiliated with Mojang, Microsoft or Epic Games.
