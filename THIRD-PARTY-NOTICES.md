# Third-party notices

Our loader, bootstrap adapter, installer and test source are MIT-licensed.
Our installer does not bundle or download another author's loader.

NeoRune 0.3.0 compiles the actor code into Blueprint bytecode. Its MIT-licensed
helper implementations are compiled into the runtime, so the release includes
the [NeoRune MIT notice](mods/ModLabLoader/Branding/NeoRune-LICENSE.txt).
NeoRune is a build-time tool; players do not install it.

The following tools are used during development and are **not distributed**
in the player installer or manual ZIP:

| Tool | License | Upstream |
| --- | --- | --- |
| UAssetAPI | MIT | https://github.com/atenfyr/UAssetAPI |
| retoc | MIT | https://github.com/trumank/retoc |
| repak | MIT OR Apache-2.0 | https://github.com/trumank/repak |
| .NET tooling | Microsoft .NET licenses | https://github.com/dotnet |

Game-derived bootstrap metadata is extracted from a local game installation
during the build. Original game containers, API dumps and generated game
bindings are not included in this repository or release. This source license
does not grant rights to the game or to third-party trademarks.

The runtime uses Epic's public
[Game Features AddComponents API](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Plugins/GameFeatures/UGameFeatureAction_AddComponents).
