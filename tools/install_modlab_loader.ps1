#Requires -Version 5.1
param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [string]$PackageDirectory,
    [ValidateSet('Install','Restore')][string]$Operation = 'Install'
)
$ErrorActionPreference = 'Stop'
if (-not [IO.Path]::IsPathRooted($GameDirectory)) { throw 'Select an absolute game folder.' }
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
function Invoke-LoaderTransaction {
$loaderGameRoot = [IO.Path]::GetFullPath($GameDirectory).TrimEnd('\','/')
$loaderModsRoot = Join-Path $loaderGameRoot 'Dungeons\Content\Paks\~mods'
$loaderBackupRoot = Join-Path $loaderGameRoot 'ModLabBackups'
$loaderStatePath = Join-Path $loaderBackupRoot 'ModLabLoader.install.json'
$loaderNames = @('ModLabLoader_P.pak','ModLabLoader_P.utoc','ModLabLoader_P.ucas')
if (@(Get-Process -Name Dungeons-Win64-Shipping,Dungeons -ErrorAction SilentlyContinue | Where-Object { -not $_.HasExited }).Count -gt 0) { throw 'Close Minecraft Dungeons II before changing loader packages.' }
if (-not (Test-Path -LiteralPath (Join-Path $loaderGameRoot 'Dungeons\Content\Paks\global.utoc'))) { throw 'Select the game folder containing Dungeons\Content\Paks\global.utoc.' }
if (-not (Test-Path -LiteralPath (Join-Path $loaderGameRoot 'Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe'))) { throw 'The selected folder has no Minecraft Dungeons II game executable.' }
function Assert-LoaderPath([string]$Path, [string]$Root) {
    $loaderAbsolute = [IO.Path]::GetFullPath($Path)
    $loaderPrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (-not $loaderAbsolute.StartsWith($loaderPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Loader transaction path is outside its owned directory.' }
    $loaderParent = Split-Path $loaderAbsolute -Parent
    while ($loaderParent.StartsWith($loaderGameRoot + '\',[StringComparison]::OrdinalIgnoreCase)) {
        if ((Test-Path -LiteralPath $loaderParent) -and ((Get-Item -LiteralPath $loaderParent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'A loader transaction directory is a junction or symbolic link.' }
        $loaderParent = Split-Path $loaderParent -Parent
    }
}
function Assert-LoaderHash([string]$Path,[string]$Hash) {
    if ((Test-Path -LiteralPath $Path) -and ((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'A loader package or backup is a symbolic link.' }
    if ($Hash -notmatch '^[0-9A-Fa-f]{64}$' -or -not (Test-Path -LiteralPath $Path) -or (Get-FileHash -LiteralPath $Path).Hash -ne $Hash) { throw "Loader file is missing or changed: $Path" }
}
$loaderState = $null
Assert-LoaderPath $loaderStatePath $loaderBackupRoot
if (Test-Path -LiteralPath $loaderStatePath) {
    if ((Get-Item -LiteralPath $loaderStatePath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Loader installation state is a symbolic link.' }
    $loaderState = Get-Content -LiteralPath $loaderStatePath -Raw | ConvertFrom-Json
    if ($loaderState.Schema -ne 1 -or $loaderState.GameDirectory -ne $loaderGameRoot) { throw 'Loader installation state belongs to another game folder.' }
    if (@($loaderState.Installed).Count -ne 3 -or @($loaderState.Installed.Name | Sort-Object -Unique).Count -ne 3) { throw 'Incomplete or duplicate owned loader state.' }
    if (@($loaderState.Originals.Path | Sort-Object -Unique).Count -ne @($loaderState.Originals).Count) { throw 'Duplicate original loader records.' }
    foreach ($loaderOriginal in $loaderState.Originals) {
        Assert-LoaderPath $loaderOriginal.Path $loaderModsRoot
        Assert-LoaderPath $loaderOriginal.Backup $loaderBackupRoot
        if ([IO.Path]::GetFileName($loaderOriginal.Path) -notmatch '^(BlueprintLoader|BetterBlueprintLoader)_P\.(pak|utoc|ucas)$') { throw 'Unexpected original loader filename.' }
        Assert-LoaderHash $loaderOriginal.Backup $loaderOriginal.SHA256
        if (Test-Path -LiteralPath $loaderOriginal.Path) { throw 'Another loader was installed after ModLab Loader; resolve the conflicting package first.' }
    }
    foreach ($loaderInstalled in $loaderState.Installed) {
        if ($loaderInstalled.Name -notin $loaderNames) { throw 'Unexpected owned package filename.' }
        $loaderInstalledPath = Join-Path (Join-Path $loaderModsRoot 'ModLabLoader') $loaderInstalled.Name
        Assert-LoaderPath $loaderInstalledPath $loaderModsRoot
        Assert-LoaderHash $loaderInstalledPath $loaderInstalled.SHA256
    }
}
if ($Operation -eq 'Restore' -and $null -eq $loaderState) { throw 'No owned ModLab Loader installation to restore.' }
if ($Operation -eq 'Install') {
    if (-not $PackageDirectory) {
        $PackageDirectory = Join-Path $PSScriptRoot '..\mods\ModLabLoader\bin\NeoRune\Pak'
        if (-not (Test-Path -LiteralPath $PackageDirectory)) { $PackageDirectory = Join-Path $PSScriptRoot 'ModLabLoader' }
    }
    $loaderManifest = Get-Content -LiteralPath (Join-Path $PackageDirectory 'ModLabLoader.manifest.json') -Raw | ConvertFrom-Json
    if ($loaderManifest.Schema -ne 1 -or $loaderManifest.SteamBuild -ne 25754144 -or @($loaderManifest.Files).Count -ne 3) { throw 'Unsupported package manifest.' }
    # Steam installations on any drive have their app manifest two levels above
    # the install folder. Other launchers require separate compatibility validation.
    $loaderSteamManifest = Join-Path (Split-Path (Split-Path $loaderGameRoot -Parent) -Parent) 'appmanifest_1912410.acf'
    if (-not (Test-Path -LiteralPath $loaderSteamManifest)) { throw 'This alpha package requires the Steam game manifest.' }
    $loaderSteamText = Get-Content -LiteralPath $loaderSteamManifest -Raw
    if ($loaderSteamText -notmatch '"appid"\s+"1912410"' -or $loaderSteamText -notmatch '"buildid"\s+"25754144"') { throw 'This alpha package supports Steam build 25754144 only.' }
    foreach ($loaderName in $loaderNames) {
        $loaderEntry = @($loaderManifest.Files | Where-Object Name -eq $loaderName)
        if ($loaderEntry.Count -ne 1) { throw 'Package manifest filenames do not match the expected triplet.' }
        Assert-LoaderHash (Join-Path $PackageDirectory $loaderName) $loaderEntry[0].SHA256
    }
}
Assert-LoaderPath $loaderStatePath $loaderBackupRoot
Assert-LoaderPath (Join-Path $loaderModsRoot 'ModLabLoader\ModLabLoader_P.pak') $loaderModsRoot
$loaderKnownOriginals = @()
if ($null -eq $loaderState) {
    foreach ($loaderUnownedName in $loaderNames) {
        if (Test-Path -LiteralPath (Join-Path (Join-Path $loaderModsRoot 'ModLabLoader') $loaderUnownedName)) { throw 'An existing ModLab Loader package has no installation record. Use manual removal or your original installer first.' }
    }
}
if ($null -eq $loaderState -and (Test-Path -LiteralPath $loaderModsRoot)) {
    $loaderKnownOriginals = @(Get-ChildItem -LiteralPath $loaderModsRoot -File -Recurse -Force | Where-Object Name -Match '^(BlueprintLoader|BetterBlueprintLoader)_P\.(pak|utoc|ucas)$')
    if (@($loaderKnownOriginals.Name | Sort-Object -Unique).Count -ne $loaderKnownOriginals.Count) { throw 'Duplicate conflicting loader packages found. Resolve the duplicate packages before installing.' }
    foreach ($loaderKnownOriginal in $loaderKnownOriginals) {
        Assert-LoaderPath $loaderKnownOriginal.FullName $loaderModsRoot
        if ($loaderKnownOriginal.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'A conflicting loader package is a symbolic link.' }
    }
}
New-Item -ItemType Directory -Path $loaderBackupRoot -Force | Out-Null
$loaderTransaction = Join-Path $loaderBackupRoot ('Loader-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
Assert-LoaderPath $loaderTransaction $loaderBackupRoot
New-Item -ItemType Directory -Path $loaderTransaction | Out-Null
$loaderStagedDirectory = Join-Path $loaderTransaction 'Staged'
if ($Operation -eq 'Install') {
    New-Item -ItemType Directory -Path $loaderStagedDirectory | Out-Null
    # Complete and verify all copies outside mounted Paks before moving the
    # installed loader. The subsequent moves stay on the game's filesystem.
    foreach ($loaderEntry in $loaderManifest.Files) {
        $loaderStagedPath = Join-Path $loaderStagedDirectory $loaderEntry.Name
        Copy-Item -LiteralPath (Join-Path $PackageDirectory $loaderEntry.Name) -Destination $loaderStagedPath
        Assert-LoaderHash $loaderStagedPath $loaderEntry.SHA256
    }
}
$loaderMoved = @()
$loaderNewFiles = @()
try {
    if ($null -ne $loaderState) {
        foreach ($loaderInstalled in $loaderState.Installed) {
            $loaderPath = Join-Path (Join-Path $loaderModsRoot 'ModLabLoader') $loaderInstalled.Name
            $loaderBackup = Join-Path $loaderTransaction $loaderInstalled.Name
            Move-Item -LiteralPath $loaderPath -Destination $loaderBackup
            $loaderMoved += @{ Path=$loaderPath; Backup=$loaderBackup; SHA256=$loaderInstalled.SHA256 }
        }
    }
    if ($Operation -eq 'Restore') {
        foreach ($loaderOriginal in $loaderState.Originals) {
            if (Test-Path -LiteralPath $loaderOriginal.Path) { throw 'Another loader file now occupies the original location.' }
            New-Item -ItemType Directory -Path (Split-Path $loaderOriginal.Path -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $loaderOriginal.Backup -Destination $loaderOriginal.Path
            $loaderNewFiles += @{ Path=$loaderOriginal.Path; SHA256=$loaderOriginal.SHA256 }
            Assert-LoaderHash $loaderOriginal.Path $loaderOriginal.SHA256
        }
        Move-Item -LiteralPath $loaderStatePath -Destination (Join-Path $loaderTransaction 'restored-install.json')
        Write-Output 'Original loader restored. ModLab settings and character saves were not changed.'
    } else {
        $loaderOriginals = @()
        if ($null -ne $loaderState) { $loaderOriginals = @($loaderState.Originals) }
        else {
            foreach ($loaderKnownOriginal in $loaderKnownOriginals) {
                    $loaderPath = $loaderKnownOriginal.FullName
                    $loaderBackup = Join-Path $loaderTransaction $loaderKnownOriginal.Name
                    $loaderHash = (Get-FileHash -LiteralPath $loaderPath).Hash
                    Move-Item -LiteralPath $loaderPath -Destination $loaderBackup
                    $loaderOriginal = @{ Path=$loaderPath; Backup=$loaderBackup; SHA256=$loaderHash }
                    $loaderMoved += $loaderOriginal; $loaderOriginals += $loaderOriginal
            }
        }
        $loaderTargetDirectory = Join-Path $loaderModsRoot 'ModLabLoader'
        New-Item -ItemType Directory -Path $loaderTargetDirectory -Force | Out-Null
        foreach ($loaderEntry in $loaderManifest.Files) {
            $loaderTarget = Join-Path $loaderTargetDirectory $loaderEntry.Name
            if (Test-Path -LiteralPath $loaderTarget) { throw 'An unowned existing ModLab Loader file would be overwritten.' }
            Move-Item -LiteralPath (Join-Path $loaderStagedDirectory $loaderEntry.Name) -Destination $loaderTarget
            $loaderNewFiles += @{ Path=$loaderTarget; SHA256=$loaderEntry.SHA256 }
            Assert-LoaderHash $loaderTarget $loaderEntry.SHA256
        }
        $loaderNextState = @{ Schema=1; GameDirectory=$loaderGameRoot; Version=$loaderManifest.Version; Originals=$loaderOriginals; Installed=@($loaderManifest.Files) }
        $loaderNextStatePath = Join-Path $loaderTransaction 'next-install.json'
        $loaderNextState | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $loaderNextStatePath -Encoding UTF8
        Move-Item -LiteralPath $loaderNextStatePath -Destination $loaderStatePath -Force
        Write-Output 'ModLab Loader installed. Previous loader packages are preserved outside the mounted Paks directory.'
    }
} catch {
    # Move only files this transaction created; keep them outside mounted Paks.
    foreach ($loaderCreated in $loaderNewFiles) {
        if (Test-Path -LiteralPath $loaderCreated.Path) {
            Assert-LoaderHash $loaderCreated.Path $loaderCreated.SHA256
            Move-Item -LiteralPath $loaderCreated.Path -Destination (Join-Path $loaderTransaction ('rollback-' + [IO.Path]::GetFileName($loaderCreated.Path)))
        }
    }
    foreach ($loaderOriginal in $loaderMoved) {
        Copy-Item -LiteralPath $loaderOriginal.Backup -Destination $loaderOriginal.Path -Force
        Assert-LoaderHash $loaderOriginal.Path $loaderOriginal.SHA256
    }
    throw
}
}
# Separate installer windows must not race one another over the same game tree.
$loaderLockPath = [IO.Path]::GetFullPath($GameDirectory).TrimEnd('\','/').ToLowerInvariant()
$loaderLockHashAlgorithm = [Security.Cryptography.SHA256]::Create()
try { $loaderLockHash = [BitConverter]::ToString($loaderLockHashAlgorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($loaderLockPath))).Replace('-','') } finally { $loaderLockHashAlgorithm.Dispose() }
$loaderMutex = New-Object Threading.Mutex($false, ('Local\ModLabLoader-' + $loaderLockHash))
$loaderLockTaken = $false
try {
    try { $loaderLockTaken = $loaderMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $loaderLockTaken = $true }
    if (-not $loaderLockTaken) { throw 'Another ModLab Loader installation is already changing this game folder.' }
    Invoke-LoaderTransaction
} finally {
    if ($loaderLockTaken) { $loaderMutex.ReleaseMutex() }
    $loaderMutex.Dispose()
}
