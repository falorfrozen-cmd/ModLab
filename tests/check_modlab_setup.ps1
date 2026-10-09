param([Parameter(Mandatory=$true)][string]$SetupPath,[Parameter(Mandatory=$true)][string]$PackageDirectory,[string]$PreviousSetupPath,[switch]$StandardSetup)
$ErrorActionPreference = 'Stop'
$checkRoot = Join-Path ([IO.Path]::GetTempPath()) ('ML-all-' + [guid]::NewGuid().ToString('N').Substring(0,12))
$checkGame = Join-Path $checkRoot 'Steam ü $literal\steamapps\common\Minecraft Dungeons II'
$checkMods = Join-Path $checkGame 'Dungeons\Content\Paks\~mods'
$checkState = Join-Path $checkGame 'ModLabBackups\ModLab.install.json'
$checkLegacy = Join-Path $checkGame 'ModLabBackups\ModLabLoader.install.json'
$checkManifest = Join-Path (Split-Path (Split-Path $checkGame -Parent) -Parent) 'appmanifest_1912410.acf'
$checkPackage = Get-Content -LiteralPath (Join-Path $PackageDirectory 'ModLab.manifest.json') -Raw | ConvertFrom-Json
function Write-Fixture([string]$Path,[string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($Path,$Text)
}
Write-Fixture (Join-Path $checkGame 'Dungeons\Content\Paks\global.utoc') 'fixture'
Write-Fixture (Join-Path $checkGame 'Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe') 'fixture'
Write-Fixture $checkManifest '"appid" "1912410" "buildid" "25754144"'
$checkSentinel = Join-Path $checkMods 'OtherMod\LeaveMe.pak'
Write-Fixture $checkSentinel 'unrelated mod'
$checkSave = Join-Path $checkGame 'SaveGames\untouched.sav'
Write-Fixture $checkSave 'untouched save sentinel'
function Snapshot($Paths) { @($Paths | ForEach-Object { @{ Path=$_; SHA256=(Get-FileHash -LiteralPath $_).Hash } }) }
function Assert-Snapshot($Records) {
    foreach ($record in $Records) { if (-not (Test-Path -LiteralPath $record.Path) -or (Get-FileHash -LiteralPath $record.Path).Hash -ne $record.SHA256) { throw ('Changed fixture: ' + $record.Path) } }
}
$checkSentinels = Snapshot @($checkSentinel,$checkSave)
function Invoke-Setup([string]$Operation,[bool]$Expected,[string]$Binary = $SetupPath) {
    $run = Join-Path ([IO.Path]::GetTempPath()) ('ModLab-run-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $run | Out-Null
    $resultPath = Join-Path $run 'result.json'
    if ($StandardSetup -and $Binary -eq $SetupPath) {
        $logPath = Join-Path $run 'setup.log'
        $worker = Start-Process -FilePath $Binary -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/SP-','/NORESTART','/CURRENTUSER',('/GAME="'+$checkGame+'"'),('/OPERATION='+$Operation),('/LOG="'+$logPath+'"')) -WindowStyle Hidden -PassThru -Wait
        if (-not (Test-Path -LiteralPath $logPath)) { throw ('Setup exited before logging; exit code: '+$worker.ExitCode) }
        $logText = [IO.File]::ReadAllText($logPath)
        $result = [pscustomobject]@{ Success=($worker.ExitCode -eq 0); Message=('Standard Setup exit '+$worker.ExitCode); Details=$logText }
    } else {
        $worker = Start-Process -FilePath $Binary -ArgumentList @('--worker',$Operation,('"'+$checkGame+'"'),('"'+$resultPath+'"')) -WindowStyle Hidden -PassThru -Wait
        if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Setup returned no result.' }
        $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    }
    if ($result.Success -ne $Expected -or (($worker.ExitCode -eq 0) -ne $Expected)) { throw ('Unexpected Setup result: ' + $result.Details) }
    Assert-Snapshot $checkSentinels
    Write-Output ($Operation + ': ' + $result.Message)
    return $result
}
function Assert-Installed {
    foreach ($entry in $checkPackage.Files) {
        $path = Join-Path $checkMods $entry.RelativePath
        if ((Get-FileHash -LiteralPath $path).Hash -ne $entry.SHA256) { throw 'Setup did not install the complete verified player package.' }
    }
}
function Assert-Removed {
    foreach ($entry in $checkPackage.Files) { if (Test-Path -LiteralPath (Join-Path $checkMods $entry.RelativePath)) { throw 'Removal left part of the combined package installed.' } }
    if (Test-Path -LiteralPath $checkState) { throw 'Removal left an active combined ownership record.' }
}
# Fresh player: one EXE installs all eight files, then updates/removes them.
Invoke-Setup Install $true | Out-Null
Assert-Installed
Invoke-Setup Install $true | Out-Null
Assert-Installed
Invoke-Setup Restore $true | Out-Null
Assert-Removed
if ($PreviousSetupPath) {
    # Upgrade the exact ownership JSON produced by the already released EXE.
    Invoke-Setup Install $true $PreviousSetupPath | Out-Null
    Invoke-Setup Install $true | Out-Null
    Assert-Installed
    Invoke-Setup Restore $true | Out-Null
    Assert-Removed
    Write-Output 'PASS previous released Setup ownership migration.'
}
# Existing Blueprint Loader in a custom directory is backed up and restored.
$oldPaths = @()
foreach ($extension in @('pak','ucas','utoc')) {
    $path = Join-Path $checkMods ('Custom folder\BlueprintLoader_P.' + $extension)
    Write-Fixture $path ('old BlueprintLoader ' + $extension); $oldPaths += $path
}
$oldSnapshot = Snapshot $oldPaths
Invoke-Setup Install $true | Out-Null
Assert-Installed
foreach ($path in $oldPaths) { if (Test-Path -LiteralPath $path) { throw 'Conflicting loader remains mounted.' } }
$beforeUpdate = Snapshot (@($checkPackage.Files | ForEach-Object { Join-Path $checkMods $_.RelativePath }) + $checkState)
$beforeOriginals = (Get-Content -LiteralPath $checkState -Raw | ConvertFrom-Json).Originals | ConvertTo-Json -Depth 6 -Compress
# Deny deletion of the last runtime file, forcing rollback after seven moves.
$locked = [IO.File]::Open((Join-Path $checkMods 'QoLSuite\BerserkerBuffs.png'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try {
    $beforeCount = @(Get-ChildItem -LiteralPath (Join-Path $checkGame 'ModLabBackups') -Directory).Count
    Invoke-Setup Install $false | Out-Null
    if (@(Get-ChildItem -LiteralPath (Join-Path $checkGame 'ModLabBackups') -Directory).Count -le $beforeCount) { throw 'Rollback fixture did not enter a transaction.' }
} finally { $locked.Dispose() }
Assert-Snapshot $beforeUpdate
Invoke-Setup Install $true | Out-Null
if (((Get-Content -LiteralPath $checkState -Raw | ConvertFrom-Json).Originals | ConvertTo-Json -Depth 6 -Compress) -ne $beforeOriginals) { throw 'Update lost the original baseline.' }
Write-Fixture $checkManifest '"appid" "1912410" "buildid" "999"'
$beforeRejection = Snapshot (@($checkPackage.Files | ForEach-Object { Join-Path $checkMods $_.RelativePath }) + $checkState)
Invoke-Setup Install $false | Out-Null
Assert-Snapshot $beforeRejection
Write-Fixture $checkManifest '"appid" "1912410" "buildid" "25754144"'
# Tampered ownership records are rejected before any file is moved.
$originalStateText = Get-Content -LiteralPath $checkState -Raw
$badState = $originalStateText | ConvertFrom-Json
$badState.Installed[7].RelativePath = '..\escape.png'
$badState | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $checkState -Encoding UTF8
Invoke-Setup Restore $false | Out-Null
Assert-Installed
[IO.File]::WriteAllText($checkState,$originalStateText)
Invoke-Setup Restore $true | Out-Null
Assert-Removed
Assert-Snapshot $oldSnapshot
# Keep former Blueprint packages outside Paks for the next fixture.
New-Item -ItemType Directory -Path (Join-Path $checkRoot 'BPL') | Out-Null
foreach ($path in $oldPaths) { Move-Item -LiteralPath $path -Destination (Join-Path $checkRoot ('BPL\' + [IO.Path]::GetFileName($path))) }
# Existing ModLab plus the standalone loader: preserve all eight old files and
# the loader's ownership record, so Remove/Restore also re-enables that record.
foreach ($entry in $checkPackage.Files) { Write-Fixture (Join-Path $checkMods $entry.RelativePath) ('previous ' + $entry.Name) }
$legacyOriginals = @()
foreach ($record in $oldSnapshot) {
    $legacyOriginals += @{ Path=$record.Path; Backup=(Join-Path $checkRoot ('BPL\' + [IO.Path]::GetFileName($record.Path))); SHA256=$record.SHA256 }
}
# Legacy backups must reside in the game's backup directory.
foreach ($record in $legacyOriginals) {
    $destination = Join-Path $checkGame ('ModLabBackups\Legacy\' + [IO.Path]::GetFileName($record.Backup))
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $record.Backup -Destination $destination; $record.Backup = $destination
}
$legacyInstalled = @($checkPackage.Files | Where-Object Name -Match '^ModLabLoader_' | ForEach-Object { @{ Name=$_.Name; SHA256=(Get-FileHash -LiteralPath (Join-Path $checkMods $_.RelativePath)).Hash } })
@{ Schema=1; GameDirectory=$checkGame; Version='0.1.0'; Installed=$legacyInstalled; Originals=$legacyOriginals } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $checkLegacy -Encoding UTF8
$baseline = Snapshot (@($checkPackage.Files | ForEach-Object { Join-Path $checkMods $_.RelativePath }) + $checkLegacy)
$locked = [IO.File]::Open((Join-Path $checkMods 'QoLSuite\QoLSuite_P.ucas'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try { Invoke-Setup Install $false | Out-Null } finally { $locked.Dispose() }
Assert-Snapshot $baseline
if (Test-Path -LiteralPath $checkState) { throw 'Failed adoption created an ownership record.' }
Invoke-Setup Install $true | Out-Null
Assert-Installed
if ((Test-Path -LiteralPath $checkLegacy) -or @((Get-Content -LiteralPath $checkState -Raw | ConvertFrom-Json).Originals).Count -ne 9) { throw 'Standalone installation was not adopted as one restorable baseline.' }
Invoke-Setup Install $true | Out-Null
Invoke-Setup Restore $true | Out-Null
Assert-Snapshot $baseline
Assert-Snapshot @($legacyOriginals | ForEach-Object { @{ Path=$_.Backup; SHA256=$_.SHA256 } })
Assert-Snapshot $baseline
Write-Output ('PASS compiled Setup: fresh install/update/removal, previous Blueprint Loader, standalone+ModLab adoption, partial-move rollback, unsupported build, invalid state, Unicode/space/dollar paths and untouched unrelated files. Evidence: ' + $checkRoot)
