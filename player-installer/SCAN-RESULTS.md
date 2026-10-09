# Installer scan record — 2026-10-10

Functional installation tests passed. Antivirus acceptance is a separate,
unresolved release requirement. No vendor has provided its detection rule.
These counts are observations at the time of review and can change.

| Candidate | Packaging / backend | EXE result | Distribution ZIP result |
| --- | --- | --- | --- |
| alpha.2 | Custom WinForms wrapper / PowerShell file transaction | 8/71 | 2/66 |
| alpha.3 | Custom WinForms wrapper / C# file transaction | 8/71 | Not independently recorded here |
| alpha.4 | Standard Inno Setup 7.1.0 / small C# worker | 1/71: SecureAge `Malicious` | 1/68: Zillya `Backdoor.Agent.Win32.101941` |

The eight gameplay/runtime files are identical in these candidates. Removing
PowerShell alone did not clear the detections. Changing to standard packaging
coincided with seven of the original eight EXE engines no longer flagging it.
This suggests packaging affected the classification; it does not establish
the precise cause or prove either remaining detection is a false positive.

## Final alpha.4 artifacts

- `ModLab-Setup-0.1.0-alpha.4.exe`: SHA-256
  `5131A94CF33606BE1CD8C556972C863BF157FA6FC45444CFA5BA270B3F445CD8`.
  [EXE report](https://www.virustotal.com/gui/file/5131a94cf33606be1cd8c556972c863bf157fa6fc45444cfa5ba270b3f445cd8).
- `ModLab-0.1.0-alpha.4.zip`: SHA-256
  `5014A2F3F8750B7B4D009295FFA1E8D93DE0C0272277CACBC546593C34019E8A`.
  [ZIP report](https://www.virustotal.com/gui/file/5014a2f3f8750b7b4d009295ffa1e8d93de0c0272277cacbc546593c34019e8a).
- Extracted `ModLabWorker.exe`: SHA-256
  `4B26D07021350B12B83EFC2D453E50436A70083AA51C9AC92B1D49961A02E8A4`.
  No separate VirusTotal report was available at review time. This is not a
  zero-detection result.

Nexus file **397** is quarantined. Earlier installer files **393** and **396**
remain preserved. The approved manual package, file **394**, stays primary:
its ZIP report showed 0/65, which is not a guarantee of safety.
[Nexus files](https://www.nexusmods.com/minecraftdungeons2/mods/147?tab=files).

The next step is review of the remaining detections and Nexus quarantine,
using the complete source and [build instructions](README.md). No antivirus
exclusion, weakened security setting, obfuscation or scan-bypass measure is
part of this installer.

Original reports: [alpha.2 EXE](https://www.virustotal.com/gui/file/6b566f2b8c4074b1107386f54728e7a935551e08ea50e58c7e22857d0b0f3cbb),
[alpha.2 ZIP](https://www.virustotal.com/gui/file/f79587893c1915f3b8509d0991536e6571a9a43fb8a76ebaba21d04522016621),
[alpha.3 EXE](https://www.virustotal.com/gui/file/4eacf10d15a3e5610fd86c0e4655178c618a1a499b560e044024559cff7264ae),
[approved manual ZIP](https://www.virustotal.com/gui/file/2bcb554b6023335805cb508e31565b563e26a4da21c93fc2e693593114b89ea8).
