# ModLab for Minecraft Dungeons II

**ModLab is an all-in-one gameplay and quality-of-life mod suite for Minecraft Dungeons II.**

## Installation

1. Close Minecraft Dungeons II.
2. Run `ModLab-Setup-0.1.0-alpha.2.exe`.
3. Select the game folder containing `Dungeons`. Steam libraries on other
   drives are detected automatically; Browse supports custom locations.
4. Click **Install / Update**. Windows may request administrator permission
   to write to the game folder.
5. Start the game through Steam and press **F10** to open ModLab.

Everything needed is included in the single ModLab installer.
The English F10 menu contains the actual embedded ModLab interface.

## Included features

- Berserker class with persistent Mastery, talents, loadouts, War Cry,
  Rampage, Ascension, buff timers and character effects.
- Smart Filter, Auto Sell and Wanted Items protection with rarity rules
  and an optional Power threshold.
- Enchant Workshop (F8), combat meter, run reports and expanded wallet.
- Boss Rush, Boss Roulette and Dungeon/Rift Directors.
- Endless Soul Storm, independent generator/completion chest reward rolls,
  all-region Soul Storm loot, generator map markers and travel, optional
  shield removal.
- Experimental Headhunter Relic.

## Updating and removing

Run the same Setup EXE again. **Install / Update** changes the gameplay suite
and loader together. **Remove / Restore** removes them together and restores
the installation present before the first combined install.

Existing ModLab files, a standalone ModLab Loader installation and known
Blueprint Loader packages are backed up under `ModLabBackups`, outside Paks.
Do not delete that folder while you need restoration. Other mods, character
saves and persisted settings are not changed by Setup. A previously installed
ModLab version will reappear on removal because it was part of the baseline.

Setup is portable: it has no background service or Windows Apps entry. Keep
the EXE or download it again for removal. Modified owned files or damaged
restore records are rejected rather than overwritten.

## Supported version

Experimental alpha for Steam build **25754144**, game **1.1.2.0**, Windows x64.
Primarily tested offline. Other game builds, launchers and multiplayer are
unverified. Direct travel to the final Dungeon/Rift ambush is unavailable.

The EXE is unsigned. Published SHA256SUMS.txt lets you verify the download.
Playing requires neither the NeoRune SDK, Python nor a .NET SDK. The installer
uses Windows PowerShell 5.1 and .NET Framework 4.8 included in Windows 10/11.

## Contents

Only these eight runtime files are installed:

```text
Dungeons/Content/Paks/~mods/ModLabLoader/ModLabLoader_P.pak
Dungeons/Content/Paks/~mods/ModLabLoader/ModLabLoader_P.ucas
Dungeons/Content/Paks/~mods/ModLabLoader/ModLabLoader_P.utoc
Dungeons/Content/Paks/~mods/QoLSuite/QoLSuite_P.pak
Dungeons/Content/Paks/~mods/QoLSuite/QoLSuite_P.ucas
Dungeons/Content/Paks/~mods/QoLSuite/QoLSuite_P.utoc
Dungeons/Content/Paks/~mods/QoLSuite/ModLab.html
Dungeons/Content/Paks/~mods/QoLSuite/BerserkerBuffs.png
```

Developer self-test scenarios, probe mods, SDKs, game executables and player
saves are not bundled. Licenses and third-party attribution are accessible
from Setup's **Licenses** link and included with the distribution ZIP.
