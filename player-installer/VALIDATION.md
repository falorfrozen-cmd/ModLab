# ModLab alpha validation

## Alpha.6 installer candidate, 2026-10-10

Alpha.6 is an installer-only candidate built from the unchanged eight runtime
files (manifest SHA-256 `A62272F6…29EF5`). Changes are limited to packaging:
custom Setup/worker icon, complete version metadata, and an optional signing
step in `tools/build_standard_installer.ps1` (`-SignToolPath` +
`-SignCertificateThumbprint`; inert without a certificate). Runtime bytes,
transaction logic, verification, backups and rollback are unchanged.

- EXE: `dist/candidates/0.1.0-alpha.6/ModLab-Setup-0.1.0-alpha.6.exe`,
  9,983,985 bytes, SHA-256 `EEE41A5B…70B89E`.
- Worker SHA-256 `CD413994…EE1E63C0`; build record
  `dist/candidates/0.1.0-alpha.6/standard-installer-build.json`.
- `tests/check_standard_worker.ps1` PASS; `tests/check_modlab_setup.ps1
  -StandardSetup -PreviousSetupPath ModLab-Setup-0.1.0-alpha.2.exe` PASS
  (fresh install/update/removal, loader adoption, rollback, invalid state,
  Unicode/space/dollar paths, alpha.2 ownership migration) under PowerShell
  7.6.5 and Windows PowerShell 5.1.
- The UTF-8 ownership-JSON reads/writes in `check_modlab_setup.ps1` are now
  encoding-explicit; Windows PowerShell 5.1 previously produced a false
  "another game folder" failure on the Unicode fixture path.
- Local Defender scans (definitions 1.459.645.0): no threats. Supporting
  evidence only; no false-positive determination is claimed.
- No VirusTotal scan of alpha.6 exists yet; upload the exact files and record
  completed results before any submission. Full analysis:
  `player-installer/AV-ANALYSIS-2026-10-10.md`.

## Component rescans, 2026-10-10

The unchanged alpha.5 EXE was reanalysed at 06:48:58 GMT+7 and now shows
3/71: Microsoft Trojan:Win32/Wacatac.B!ml, SecureAge Malicious and Zillya
Backdoor.Agent.Win32.101941. The worker upload succeeded through the in-app
browser; its separate 06:50:10 report shows 3/71: Bkav Pro, McAfee Scanner
and SecureAge. Microsoft and Zillya report Undetected for the worker.
The differing component results do not identify a specific vendor rule.

Defender definitions were updated to 1.459.645.0; scan-only custom scans of
both preserved samples reported no threats and exit code 0. Real-time
protection remained enabled. This local result does not override VirusTotal.
No runtime or uploaded artifact was changed for these checks.

SecureAge's official form accepted the original EXE and source/report evidence
and displayed Report Submitted. Zillya's form subsequently displayed
Submitted successfully. Both used the verified author contact address.
These acknowledgements confirm delivery, not reclassification or Nexus approval.
No confirmed false-positive determination is claimed.
Exact hashes, times and report links are in the public installer scan record.

## Review request and artifact audit, 2026-10-10

The original Gmail send used the wrong account. The request was resent from
the verified author account, falorfrozen@gmail.com, at 06:25 on 2026-10-10.
Gmail's sent-message details confirmed that account and support@nexusmods.com.
The correction explicitly identifies the earlier sender error. No review
approval has been received.

The Nexus Files page was subsequently verified: file 399 is quarantined,
not still processing. Manual package 394 remains downloadable. The EXE's
initial report showed 2/71 (SecureAge and Zillya); see the subsequent rescan above.

The EXE sandbox report's dropped Inno setup process has a separate 0/71
report. The process tree did not show ModLabWorker.exe or a completed
installation. Behavior labels cannot substitute for a worker scan or establish
which bytes caused the static detections. Initially the alpha.5 worker had no separate
report; public upload attempts through the report overlay and the home page
both failed with VirusTotal's incorrectObject error.
Chrome file-URL access was already enabled, as confirmed by the user; the error
is not evidence of missing extension permission. The subsequent successful
upload is recorded above; no worker scan pass is claimed.

Build integrity controls were added without changing the installer runtime:
valid Microsoft/Pyrsys compiler signatures are required, compiler/manifest
hashes are recorded, and existing release outputs are protected against
overwriting and concurrent builds. Tests rejected unsigned and wrong-publisher
tools and preserved an existing output sentinel. An isolated rebuild passed
the actual compiled Setup transaction suite and worker integrity/8.3 checks.
No rebuilt bytes were uploaded or substituted for alpha.5.

A review request for Nexus file 399 was sent to support@nexusmods.com; Gmail
confirmed SENT. The request includes source, artifact hashes, build/test
instructions and the two unresolved detections. This is not Nexus approval.

Microsoft Defender platform 4.18.26080.4, definitions 1.459.641.0, completed
custom scans of the existing alpha.5 EXE and its prepared payload directory
with no threats reported. Real-time protection remained enabled. This local
result does not clear SecureAge or Zillya's EXE classifications.

An independent compilation of the public worker source with the original
build identity matched 95 method records, including 94 IL bodies, assembly
references, literal constants and P/Invoke declarations. The two assemblies
were inspected in separate Windows PowerShell 5.1 reflection-only processes;
neither worker was executed for the comparison. This is not a byte-for-byte
reproducible-build claim or comprehensive security certification.

PE inspection identified the worker as an IL-only x64 .NET assembly with no
overlay. Its sole declared P/Invoke is kernel32.dll / GetLongPathName. The
Microsoft C# and Pyrsys Inno compiler signatures are valid; the Setup and
worker are unsigned. All eight runtime inputs still match the manifest.
The uploaded alpha.5 EXE and ZIP hashes remain unchanged.

Further evidence and exact hashes are in the public
player-player-installer/SCAN-RESULTS.md record. No established false positive or
resolved antivirus warning is claimed.

## Alpha.5 Temp path compatibility, 2026-10-10

The first clean GitHub runner exposed a failure in alpha.4: Inno extracted
under an 8.3 user-path alias while TEMP used the long name. The worker rejected
that valid directory before any game mutation. Alpha.5 normalizes both existing
paths through Windows GetLongPathName before checking the Temp prefix, retaining
the directory and reparse-point restrictions. Alpha.4's upload and scan are
preserved; its reports do not certify the changed alpha.5 executable.

The actual alpha.5 EXE passed the complete temporary-fixture suite, including
original alpha.2 installation migration. The compiled worker also passed actual
discovery through an 8.3 alias with a process-local Temp override, occupied
result rejection and changed manifest rejection. Runtime hashes are unchanged.
The complete public clean Windows workflow passed for source commit
`30899a0542930bbe4197eb133a95a14598233765`:
https://github.com/falorfrozen-cmd/ModLab/actions/runs/37970294182.
The private repository's corresponding workflow also passed. These checks
use fixture data, not a native game session or antivirus certification.
The final EXE scan showed 2/71 (SecureAge and Zillya). Its ZIP showed 0/61,
with Zillya timing out and SecureAge unable to process the archive; the ZIP
result does not clear the EXE detections. Nexus file 399 was subsequently
verified as quarantined. The approved manual package remains recommended.
Exact hashes and report links are in the public installer scan record.

## Alpha.4 standard installer validation, 2026-10-10

The same C# transaction engine is wrapped by standard Inno Setup 7.1.0.
The worker contains no embedded archive or gameplay assets. The standard
installer stores the eight unchanged alpha.2 runtime files as normal file
entries and binds its manifest with a compiled SHA-256. All installation
operations still run in C#; no PowerShell script is executed.

The final compiled standard EXE passed the complete install/update/remove,
legacy loader adoption, original alpha.2 ownership migration, locked-file
rollback, altered ownership and unsupported-build scenarios in temporary
fixtures. Fixture runs use Inno's supported `/CURRENTUSER` mode, so tests do
not require UAC permission or touch the actual protected Steam installation.
Normal player startup requests UAC permission for protected game folders.

Additional checks ran the actual compiled worker from a temporary extraction:
an occupied result destination and changed manifest were rejected before
any game mutation. UTF-8 result and discovery files are used by the wizard.
The eight runtime SHA-256 values remain identical to alpha.2.

Antivirus acceptance is tracked separately from functional tests. Alpha.3's
C#-only custom EXE still produced the same 8/71 detections as alpha.2, so
removing PowerShell did not establish the cause. The final alpha.4 EXE showed
1/71 (SecureAge: Malicious); its distribution ZIP separately showed 1/68
(Zillya: Backdoor.Agent.Win32.101941). Nexus file 397 remains quarantined.
No vendor rule has been disclosed and no safety guarantee is claimed. The
approved manual package remains primary. The public installer source includes
the exact artifact hashes and report links in `player-player-installer/SCAN-RESULTS.md`.

## Alpha.3 installer-only validation, 2026-10-10

The eight installed runtime files are byte-identical to the alpha.2 player
package. The installer backend was ported to managed C#; the distributed EXE
contains no PowerShell script and does not launch an interpreter or change
execution policy. Developer rendering is excluded from the player build.

The compiled EXE passed fresh install, update, removal, exact restoration of
previous Blueprint Loader files, standalone loader adoption, and rollback
after partially moving locked files. A second run installed using the original
alpha.2 EXE, then updated and removed with alpha.3; ownership format and restore
baseline remained compatible. Unrelated mod and save sentinels remained unchanged.

Twenty-three detection, argument, license, integrity and guard checks passed,
including a corrupt runtime, an unowned backup path, another installer holding
the named lock and an actual process named Dungeons. These exercise the new C#
backend directly. Unsupported builds and altered installed destinations were
also rejected by the compiled Setup EXE. Paths include Unicode, spaces and `$`.

This verifies installer behavior, not antivirus acceptance. The original
alpha.2 EXE's VirusTotal report showed 8/71 detections; its distribution ZIP
showed 2/66. No exact vendor rule or malicious code was identified by those
labels. The alpha.3 EXE's separate scan also showed 8/71 detections. Removing
PowerShell alone did not clear them. The standard alpha.4 wrapper is the
subsequent candidate, not a claim that the alpha.3 detection was resolved.

## Earlier gameplay and alpha.2 validation

Validated on Windows x64 for Steam build 25754144 / game 1.1.2.0, 2026-10-09.

Alpha.2 changes presentation and documentation. The eight gameplay/runtime
files are unchanged from alpha.1. Its compiled ModLab Setup was retested for
fresh installation, updating, adoption, removal, rollback and invalid input.

## Player build

QoLSuite was rebuilt with `QoLRunSelfTests=false` and `NeoRuneInstall=false`
into a separate output directory: zero compiler warnings or errors. Its
project excludes diagnostic test scenarios from normal player builds.
The loader triplet is the same SHA-256-verified runtime used in the independent
loader's native validation. The complete installer embeds exactly eight runtime
files, a manifest, its original transaction script and license notices.

## Compiled installer

The actual Setup EXE, including its embedded runtime payload, was exercised
through its hidden worker with Windows PowerShell 5.1. Checks passed for:

- Fifteen detection, argument quoting and license checks.
- Fresh install, update and complete removal without a previous loader.
- Existing Blueprint Loader in a custom mods subdirectory; exact restoration.
- Existing standalone ModLab Loader plus all five prior ModLab files;
  adoption, update and exact restoration of all nine baseline files, including
  the standalone loader ownership record and its untouched backup archives.
- Locked late runtime files causing partial moves; rollback restored exact
  pre-operation runtime hashes and ownership state.
- Preserving the original restore baseline across updates.
- Rejecting an unsupported Steam build, altered ownership destination and
  corrupted runtime download before changes.
- Paths with spaces, Unicode and a literal dollar sign.
- Preserving unrelated mod and save-sentinel files.
- Refusing package changes while the game is running.

Setup's rendered English window was visually checked for clipping.

The compiled EXE was also installed and updated in the actual Steam game
folder. All eight installed runtime hashes matched the player manifest. Its
nine existing baseline files, including the previous standalone loader record,
were adopted as backups. All character/settings save hashes remained unchanged.

## Native game check

The native diagnostic variant of the same gameplay sources was run with the
independent loader in quiet mode. It entered a Dungeon and passed six actual
F10 open/save/close cycles with different cursor and mouse-capture states.
Browser focus was released and native character movement succeeded after each
close. No loader diagnostic save was generated. The runner restored the
original save directory and verified its hashes.

The latest run exited with **0xC0000005 after the gameplay checks passed**.
This is not counted as a clean overall native test pass. Earlier independent
loader runs exited cleanly; the wider shutdown issue has also occurred in
package-free controls. This release does not claim to resolve it.

These checks do not establish compatibility with other game builds, launchers
or multiplayer, nor certify every gameplay feature in this alpha.

## alpha.7 portable installer candidate (2026-10-10)

Only the installation application and distribution layout changed. The eight
runtime files and their manifest are byte-identical to alpha.6 and the actual
installed game runtime. `NativeTransaction.cs` and `SteamDiscovery.cs` were
reused without source changes. The real game installation was not modified.

The exact `ModLab.exe`, SHA-256
`D6436B1C3A57CAAE41BB20D3D78C8AF147076C331A17B461C6C0665BE65B6D62`,
was tested after extraction from the complete distribution ZIP, SHA-256
`87F7656BA3A30C4EE310F34B0F121755A25FA5F3B3DAE716610B0A51E6456DCE`.
`tests/check_portable_setup.ps1` passed under PowerShell 7.6.5 and Windows
PowerShell 5.1, including the existing compiled transaction suite and migration
from the released alpha.2 Setup. Additional checks rejected an occupied result
destination, altered or missing external manifest, and an altered runtime file
before any game mutation. Local Defender reported no threats for this EXE.

The new GUI has not been visually exercised. Completed VirusTotal scans on
2026-10-10 report **2/71** for the exact EXE (McAfee Scanner and SecureAge) and
**0/66** for the ZIP. SecureAge could not process the ZIP and Zillya failed on
the archive, so that result does not clear the separately flagged EXE. The
empty Inno engine control reports **0/71**. This is a candidate only; it has
not been published or approved on Nexus. Functional test success and local
Defender scans do not resolve the two remaining detections.
