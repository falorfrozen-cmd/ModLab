# Installer scan record — 2026-10-10

Functional installation tests passed. Antivirus acceptance is a separate,
unresolved release requirement. No vendor has provided its detection rule.
These counts are observations at the time of review and can change.

## Latest completed scans — alpha.7 portable candidate and controls

All three browser-upload verifications completed on 2026-10-10. The exact
artifacts are preserved; none is promoted as an approved public installer.

| Artifact | Completed result | Analysis time (GMT+7) |
| --- | --- | --- |
| [alpha.7 ModLab.exe](https://www.virustotal.com/gui/file/d6436b1c3a57caae41bb20d3d78c8af147076c331a17b461c6c0665be65b6d62) | **2/71** — McAfee Scanner `Ti!D6436B1C3A57`, SecureAge `Malicious` | 11:43:49 |
| [alpha.7 complete ZIP](https://www.virustotal.com/gui/file/87f7656ba3a30c4ee310f34b0f121755a25fa5f3b3dae716610b0a51e6456dce) | **0/66** — SecureAge unsupported; Zillya failure | 11:43:05 |
| [Empty Inno engine control](https://www.virustotal.com/gui/file/afe788a9439ad514a991beac7e5566968680222ebbe7e59f6180c75125b281bc) | **0/71** — no ModLab payload or custom code | 11:43:29 |

The alpha.7 application embeds no runtime archive, extracts no executable and
starts no worker. It reuses the unchanged file transaction and Steam discovery
sources. Microsoft, Zillya and Bkav Pro reported Undetected for this EXE at
the recorded time. The complete ZIP was tested after extraction under
PowerShell 7.6.5 and Windows PowerShell 5.1: installation, update, restoration,
alpha.2 migration, partial-move rollback and integrity rejection passed. The
new GUI was not visually exercised in this session. All eight runtime hashes
are unchanged. [Build instructions](PORTABLE-BUILDING.md).

A separate [native-files Inno prototype](https://www.virustotal.com/gui/file/00f808d85ea326af0423dbe99e35f79265e46bf1bb16f8b17300bbcfefc9cfb9)
without a custom worker or script still reported **2/71** (SecureAge and Zillya)
at 10:36:50. The empty Inno control and this prototype show that the Inno
engine alone and a separate worker are not sufficient explanations for every
observed detection. They do not reveal the vendors' rules or prove a false
positive. Packaging changes alone have not eliminated all detections.

## alpha.6 candidate — completed installer and worker scans

alpha.6 is a local installer-only candidate built from the unchanged eight
runtime files. It addresses the concrete packaging gaps identified in the
2026-10-10 analysis ([AV-ANALYSIS-2026-10-10.md](AV-ANALYSIS-2026-10-10.md)):

- custom Setup/worker icon (replaces Inno Setup's shared default icon);
- complete version metadata on both binaries;
- optional code-signing step in the build (worker signed before it is
  embedded, Setup signed after compilation; inert without a certificate).

- EXE SHA-256: `EEE41A5B418B0963AB865D81DC6ECC941B48E42004A443F96173D5E36E70B89E`
  (9,983,985 bytes).
- Worker SHA-256: `CD413994F9BC98E5AE7EF10F7AA08E15B5F0E6D698890DDAEE331E62EE1E63C0`.
- Manifest unchanged: `A62272F64CC4BABF50AE5B5609719967B94BBA46A5D7EDE401F5D7AB42D29EF5`.

`check_standard_worker.ps1` and `check_modlab_setup.ps1 -StandardSetup
-PreviousSetupPath <alpha.2>` passed under PowerShell 7.6.5 and Windows
PowerShell 5.1 (including alpha.2 ownership migration, rollback and
Unicode/space/dollar fixture paths). Local Defender scans reported no threats
(supporting evidence only). Completed VirusTotal reports show:

- [EXE](https://www.virustotal.com/gui/file/eee41a5b418b0963ab865d81dc6ecc941b48e42004a443f96173d5e36e70b89e):
  **2/71**, SecureAge and Zillya, 09:52:39 GMT+7.
- [Worker](https://www.virustotal.com/gui/file/cd413994f9bc98e5ae7ef10f7aa08e15b5f0e6d698890ddaee331e62ee1e63c0):
  **3/71**, Bkav Pro, McAfee Scanner and SecureAge, 09:55:31 GMT+7.

Microsoft reported Undetected for both at those times. The candidate remains
unapproved. Code signing identifies a publisher and protects file integrity;
it does not guarantee warning-free downloads or zero antivirus detections.

## Latest component checks, 06:48–06:50 GMT+7

The unchanged alpha.5 EXE was reanalysed on 2026-10-10 at 06:48:58.
Its completed report now shows **3/71**: Microsoft
`Trojan:Win32/Wacatac.B!ml`, SecureAge `Malicious` and Zillya
`Backdoor.Agent.Win32.101941`. The earlier 2/71 result below is historical.

The worker upload succeeded through the in-app browser after the Chrome
upload flow returned `incorrectObject`. This is a working alternative,
not a proven explanation of that frontend error. The exact released worker
was scanned separately at 06:50:10; its completed report shows **3/71**:
Bkav Pro `W32.Malware.D6FBBCF1`, McAfee Scanner `Ti!56E2CECBA9FC`, and
SecureAge `Malicious`. Microsoft and Zillya report `Undetected` for this
worker. This narrows which artifacts those engines flag, without establishing
why, certifying the runtime, or confirming a false positive.
[Worker report](https://www.virustotal.com/gui/file/56e2cecba9fc421733b151b0a0fc8577db80960c848919bc16f578ae90f28da1).

Microsoft Defender definitions were updated to **1.459.645.0**. Scan-only
custom scans of the unchanged EXE and worker each returned `found no threats`
and exit code 0. Real-time protection remained enabled; no exclusions or
global security changes were made. The local result differs from the
Microsoft VirusTotal result and does not override it.

SecureAge's official form accepted the preserved EXE, source/report links
and a request to identify any unsafe behavior. It displayed **Report
Submitted**, stating that the submission went to the detection team.
Zillya's official form subsequently displayed **Submitted successfully!**.
Both forms used the verified author contact address and the original EXE.
These are delivery confirmations, not classification changes or Nexus approval.

[VirusTotal's guidance](https://docs.virustotal.com/docs/false-positive-contacts)
recommends rescanning and then contacting the detecting vendor; VirusTotal
cannot modify the vendors' scan decisions. No random recompilation,
hash-changing variant, security exclusion or replacement Nexus upload was used.

Alpha.5 fixes a real alpha.4 compatibility failure caught by clean Windows CI:
the helper compared an 8.3 Temp alias against a long TEMP path. The corrected
worker resolves both existing names before validating the Temp prefix. The
actual compiled EXE and the [clean Windows workflow](https://github.com/falorfrozen-cmd/ModLab/actions/runs/37970294182)
passed. This is a functional fix, independent of antivirus classification.
Alpha.5 was submitted as Nexus file **399**. Its initial EXE report showed **2/71**:
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
Initially its separate VirusTotal classification could not be verified. Public upload
attempts through the report overlay and home page failed with
`incorrectObject:true`. File-URL access was already enabled in the browser
extension; this is not evidence of a missing permission. Those attempts did
not complete a scan. The subsequent successful upload is recorded above.
No exact detection rule or confirmed false-positive decision is available for
the flagged EXE engines.

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
