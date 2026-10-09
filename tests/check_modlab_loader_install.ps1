param([Parameter(Mandatory=$true)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
$loaderTestRepo = Split-Path $PSScriptRoot -Parent
$loaderTestRoot = Join-Path $loaderTestRepo ('diagnostics\loader-install-' + [guid]::NewGuid().ToString('N'))
$loaderTestGame = Join-Path $loaderTestRoot 'steamapps\common\Minecraft Dungeons II'
$loaderTestMods = Join-Path $loaderTestGame 'Dungeons\Content\Paks\~mods'
$loaderTestInstaller = Join-Path $loaderTestRepo 'tools\install_modlab_loader.ps1'
$loaderTestPackage = $PackageDirectory
New-Item -ItemType Directory -Path (Join-Path $loaderTestMods 'BlueprintLoader') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $loaderTestGame 'Dungeons\Binaries\Win64') -Force | Out-Null
[IO.File]::WriteAllBytes((Join-Path $loaderTestGame 'Dungeons\Content\Paks\global.utoc'),[byte[]]@(1,2,3))
[IO.File]::WriteAllBytes((Join-Path $loaderTestGame 'Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe'),[byte[]]@(4,5,6))
[IO.File]::WriteAllText((Join-Path $loaderTestRoot 'steamapps\appmanifest_1912410.acf'),'"AppState" { "appid" "1912410" "buildid" "25754144" }')
$loaderTestOriginals = @()
foreach ($loaderTestExtension in @('pak','utoc','ucas')) {
    $loaderTestPath = Join-Path (Join-Path $loaderTestMods 'BlueprintLoader') ('BlueprintLoader_P.' + $loaderTestExtension)
    [IO.File]::WriteAllText($loaderTestPath,'original-' + $loaderTestExtension)
    $loaderTestOriginals += @{ Path=$loaderTestPath; Hash=(Get-FileHash -LiteralPath $loaderTestPath).Hash }
}
$loaderTestUnrelated = Join-Path $loaderTestMods 'player-notes.txt'
[IO.File]::WriteAllText($loaderTestUnrelated,'keep this file')
$loaderTestUnrelatedHash = (Get-FileHash -LiteralPath $loaderTestUnrelated).Hash
function Assert-InstallCheck([bool]$Condition,[string]$Reason) { if (-not $Condition) { throw $Reason } }
& $loaderTestInstaller -GameDirectory $loaderTestGame -PackageDirectory $loaderTestPackage
foreach ($loaderTestOriginal in $loaderTestOriginals) { Assert-InstallCheck (-not (Test-Path -LiteralPath $loaderTestOriginal.Path)) 'Original loader is still mounted.' }
$loaderTestState = Get-Content (Join-Path $loaderTestGame 'ModLabBackups\ModLabLoader.install.json') -Raw | ConvertFrom-Json
foreach ($loaderTestOriginal in $loaderTestState.Originals) {
    Assert-InstallCheck ((Get-FileHash -LiteralPath $loaderTestOriginal.Backup).Hash -eq $loaderTestOriginal.SHA256) 'Original loader backup changed.'
}
# Upgrade from the same verified package; original backups must still point to
# the original loader, while the replaced ModLab triplet is retained separately.
& $loaderTestInstaller -GameDirectory $loaderTestGame -PackageDirectory $loaderTestPackage
$loaderTestUpgraded = Get-Content (Join-Path $loaderTestGame 'ModLabBackups\ModLabLoader.install.json') -Raw | ConvertFrom-Json
Assert-InstallCheck (($loaderTestUpgraded.Originals | ConvertTo-Json -Compress) -eq ($loaderTestState.Originals | ConvertTo-Json -Compress)) 'Upgrade lost the original loader backup.'
& $loaderTestInstaller -GameDirectory $loaderTestGame -Operation Restore
foreach ($loaderTestOriginal in $loaderTestOriginals) { Assert-InstallCheck ((Get-FileHash -LiteralPath $loaderTestOriginal.Path).Hash -eq $loaderTestOriginal.Hash) 'Original loader restore mismatch.' }
Assert-InstallCheck ((Get-FileHash -LiteralPath $loaderTestUnrelated).Hash -eq $loaderTestUnrelatedHash) 'An unrelated file changed.'
Assert-InstallCheck (-not (Test-Path -LiteralPath (Join-Path $loaderTestMods 'ModLabLoader\ModLabLoader_P.utoc'))) 'Owned loader remained enabled after restore.'
# A damaged package must be rejected before any installed loader is moved.
$loaderTestDamaged = Join-Path $loaderTestRoot 'Damaged'
Copy-Item -LiteralPath $loaderTestPackage -Destination $loaderTestDamaged -Recurse
[IO.File]::WriteAllBytes((Join-Path $loaderTestDamaged 'ModLabLoader_P.ucas'),[byte[]]@(9))
$loaderTestRejected = $false
try { & $loaderTestInstaller -GameDirectory $loaderTestGame -PackageDirectory $loaderTestDamaged } catch { $loaderTestRejected = $true }
Assert-InstallCheck $loaderTestRejected 'A damaged package was accepted.'
foreach ($loaderTestOriginal in $loaderTestOriginals) { Assert-InstallCheck ((Get-FileHash -LiteralPath $loaderTestOriginal.Path).Hash -eq $loaderTestOriginal.Hash) 'Failed installation changed the original loader.' }
# Force a move failure after at least one original package has moved. The real
# transaction must put all originals back and leave no active replacement.
$loaderTestLockedPath = Join-Path (Join-Path $loaderTestMods 'BlueprintLoader') 'BlueprintLoader_P.ucas'
$loaderTestBackupPaksBefore = @(Get-ChildItem -LiteralPath (Join-Path $loaderTestGame 'ModLabBackups') -Filter 'BlueprintLoader_P.pak' -File -Recurse).Count
$loaderTestStream = [IO.File]::Open($loaderTestLockedPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$loaderTestRollbackCaught = $false
try { & $loaderTestInstaller -GameDirectory $loaderTestGame -PackageDirectory $loaderTestPackage } catch { $loaderTestRollbackCaught = $true } finally { $loaderTestStream.Dispose() }
Assert-InstallCheck $loaderTestRollbackCaught 'The locked loader package did not reject replacement.'
$loaderTestBackupPaksAfter = @(Get-ChildItem -LiteralPath (Join-Path $loaderTestGame 'ModLabBackups') -Filter 'BlueprintLoader_P.pak' -File -Recurse).Count
Assert-InstallCheck ($loaderTestBackupPaksAfter -gt $loaderTestBackupPaksBefore) 'The rollback fixture did not reach a partial original-package move.'
foreach ($loaderTestOriginal in $loaderTestOriginals) { Assert-InstallCheck ((Get-FileHash -LiteralPath $loaderTestOriginal.Path).Hash -eq $loaderTestOriginal.Hash) 'Rollback failed to restore an original package.' }
Assert-InstallCheck (-not (Test-Path -LiteralPath (Join-Path $loaderTestMods 'ModLabLoader\ModLabLoader_P.pak'))) 'Rollback left a replacement enabled.'
# Unexpected Steam builds must be rejected before transaction directories appear.
$loaderTestManifestPath = Join-Path $loaderTestRoot 'steamapps\appmanifest_1912410.acf'
[IO.File]::WriteAllText($loaderTestManifestPath,'"appid" "1912410" "buildid" "999"')
$loaderTestBuildRejected = $false
try { & $loaderTestInstaller -GameDirectory $loaderTestGame -PackageDirectory $loaderTestPackage } catch { $loaderTestBuildRejected = $true }
Assert-InstallCheck $loaderTestBuildRejected 'An unsupported Steam build was accepted.'
[IO.File]::WriteAllText($loaderTestManifestPath,'"appid" "1912410" "buildid" "25754144"')
# Detect a known loader moved into a custom folder, including restoration to it.
$loaderTestCustom = Join-Path $loaderTestMods 'Custom Loader Folder'
New-Item -ItemType Directory -Path $loaderTestCustom | Out-Null
foreach ($loaderTestOriginal in $loaderTestOriginals) {
    $loaderTestCustomPath = Join-Path $loaderTestCustom ([IO.Path]::GetFileName($loaderTestOriginal.Path))
    Move-Item -LiteralPath $loaderTestOriginal.Path -Destination $loaderTestCustomPath
    $loaderTestOriginal.Path = $loaderTestCustomPath
}
& $loaderTestInstaller -GameDirectory $loaderTestGame -PackageDirectory $loaderTestPackage
$loaderTestDuplicateStatePath = Join-Path $loaderTestGame 'ModLabBackups\ModLabLoader.install.json'
$loaderTestStateBytes = [IO.File]::ReadAllBytes($loaderTestDuplicateStatePath)
$loaderTestDuplicateState = Get-Content -LiteralPath $loaderTestDuplicateStatePath -Raw | ConvertFrom-Json
$loaderTestDuplicateState.Installed[1] = $loaderTestDuplicateState.Installed[0]
$loaderTestDuplicateState | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $loaderTestDuplicateStatePath -Encoding UTF8
$loaderTestStateRejected = $false
try { & $loaderTestInstaller -GameDirectory $loaderTestGame -PackageDirectory $loaderTestPackage } catch { $loaderTestStateRejected = $true }
Assert-InstallCheck $loaderTestStateRejected 'A duplicate owned state was accepted.'
[IO.File]::WriteAllBytes($loaderTestDuplicateStatePath,$loaderTestStateBytes)
& $loaderTestInstaller -GameDirectory $loaderTestGame -Operation Restore
foreach ($loaderTestOriginal in $loaderTestOriginals) { Assert-InstallCheck ((Get-FileHash -LiteralPath $loaderTestOriginal.Path).Hash -eq $loaderTestOriginal.Hash) 'Custom-folder restore mismatch.' }
Write-Output "PASS install, upgrade, restore, unrelated-file preservation, damaged-package/build/state rejection, partial-move rollback and custom-folder loader discovery. Evidence: $loaderTestRoot"
