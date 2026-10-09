# Installer scan record — 2026-10-10

Functional installation tests passed. Antivirus acceptance is a separate,
unresolved release requirement. No vendor has provided its detection rule.
These counts are observations at the time of review and can change.

Alpha.5 fixes a real alpha.4 compatibility failure caught by clean Windows CI:
the helper compared an 8.3 Temp alias against a long TEMP path. The corrected
worker resolves both existing names before validating the Temp prefix. The
actual compiled EXE and the [clean Windows workflow](https://github.com/falorfrozen-cmd/ModLab/actions/runs/37970294182)
passed. This is a functional fix, independent of antivirus classification.
Alpha.5 was submitted as Nexus file **399**. Its EXE shows **2/71**:
SecureAge `Malicious` and Zillya `Backdoor.Agent.Win32.101941`. The completed
ZIP report shows **0/61**, with Zillya timing out and SecureAge unable to
process the archive. This does not clear the EXE's two detections. The Nexus
Files page was verified on 2026-10-10: file **399 is quarantined**. The
approved manual package, file **394**, remains downloadable. Alpha.4 reports
below do not apply to the changed EXE.

Alpha.5 EXE SHA-256:
`95BBBE3C1435A94087B8D835BF33F891C7DE0A2F3A4B1E30DB4D8B916E920B69`.
[EXE report](https://www.virustotal.com/gui/file/95bbbe3c1435a94087b8d835bf33f891c7de0a2f3a4b1e30db4d8b916e920b69).
Alpha.5 ZIP SHA-256:
`8411C2D94171167373CA15B1B5131BFFDD5911BD446B2C016EED31A7F527C7CC`.
[ZIP report](https://www.virustotal.com/gui/file/8411c2d94171167373ca15b1b5131bffdd5911bd446b2c016eed31a7f527c7cc).

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

## Review request and additional checks

The author sent a review request for file **399** to `support@nexusmods.com`
on **2026-10-10**. An initial send used the wrong Gmail account. A corrected
request was sent from the verified author account at 06:25 local time;
Gmail's sent-message details confirmed the sender and recipient. The request
includes the source revision, hashes, build/test instructions, CI evidence
and both remaining detections. Sending the request is not Nexus approval.

Further checks used the existing alpha.5 files; the uploaded EXE and ZIP
hashes above remain unchanged:

- Microsoft Defender platform `4.18.26080.4`, definitions `1.459.641.0`,
  completed custom scans of the installer EXE and its prepared payload
  directory and reported no threats. Real-time protection remained enabled.
  This is a local Defender result, not clearance by SecureAge or Zillya.
- An independent compilation of the public worker source and the original
  build identity matched the released build worker's **95 method records**
  (including 94 IL bodies),
  assembly references, literal constants and P/Invoke declarations. Metadata
  was read in separate reflection-only processes without running either
  worker. This comparison is not a byte-for-byte reproducible-build claim or
  a comprehensive security certification.
- The worker is an IL-only x64 .NET assembly with no PE overlay. Its only
  declared P/Invoke is `kernel32.dll` / `GetLongPathName`, used to resolve Temp
  path aliases. All eight runtime inputs still match their manifest.
- Windows reports the Microsoft C# compiler and Pyrsys Inno compiler
  Authenticode signatures as valid. The ModLab Setup and worker themselves
  remain unsigned.

Current alpha.5 build worker SHA-256:
`56E2CECBA9FC421733B151B0A0FC8577DB80960C848919BC16F578AE90F28DA1`.
Its separate VirusTotal classification could not be verified. Public upload
attempts through the report overlay and home page failed with
`incorrectObject:true`. File-URL access was already enabled in the browser
extension; this is not evidence of a missing permission. No scan was completed.
No exact detection rule or confirmed false-positive decision is available for
the two flagged EXE engines.

The EXE's sandbox process tree showed a dropped Inno setup executable with a
separate **0/71** report, SHA-256
`CC98F1B920476ECBFB85773308FD13C5F7D52F2FA500ECB4A9DAB3295AE42009`.
[Dropped setup report](https://www.virustotal.com/gui/file/cc98f1b920476ecbfb85773308fd13c5f7d52f2fa500ecb4a9dab3295ae42009).
The tree did not show the ModLab worker or a completed installation. This
result cannot clear the outer EXE, certify the worker or identify the cause
of the remaining static detections.

Build-time controls now require valid Microsoft/Pyrsys compiler signatures,
record tool and manifest hashes and prevent replacement of an existing
release output. An exclusive lock prevents simultaneous builds of the same
version/output. An isolated build passed the compiled Setup transaction suite
and worker integrity/8.3 path checks. No replacement artifact was uploaded;
the alpha.5 hashes above remain unchanged. These controls improve build
integrity and do not clear antivirus detections.

Original reports: [alpha.2 EXE](https://www.virustotal.com/gui/file/6b566f2b8c4074b1107386f54728e7a935551e08ea50e58c7e22857d0b0f3cbb),
[alpha.2 ZIP](https://www.virustotal.com/gui/file/f79587893c1915f3b8509d0991536e6571a9a43fb8a76ebaba21d04522016621),
[alpha.3 EXE](https://www.virustotal.com/gui/file/4eacf10d15a3e5610fd86c0e4655178c618a1a499b560e044024559cff7264ae),
[approved manual ZIP](https://www.virustotal.com/gui/file/2bcb554b6023335805cb508e31565b563e26a4da21c93fc2e693593114b89ea8).
