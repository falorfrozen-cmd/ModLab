param([Parameter(Mandatory=$true)][string]$SetupPath)
$ErrorActionPreference = 'Stop'
$loaderExeRepo = Split-Path $PSScriptRoot -Parent
$loaderExeTestRoot = Join-Path ([IO.Path]::GetTempPath()) ('ML-setup-' + [guid]::NewGuid().ToString('N').Substring(0,12))
$loaderExeGame = Join-Path $loaderExeTestRoot 'Steam Library ü $literal\steamapps\common\Minecraft Dungeons II'
$loaderExeMods = Join-Path $loaderExeGame 'Dungeons\Content\Paks\~mods'
New-Item -ItemType Directory -Path (Join-Path $loaderExeMods 'BlueprintLoader') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $loaderExeGame 'Dungeons\Binaries\Win64') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $loaderExeGame 'Dungeons\Content\Paks\global.utoc'),'fixture')
[IO.File]::WriteAllText((Join-Path $loaderExeGame 'Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe'),'fixture')
$loaderExeManifest = Join-Path (Split-Path (Split-Path $loaderExeGame -Parent) -Parent) 'appmanifest_1912410.acf'
[IO.File]::WriteAllText($loaderExeManifest,'"appid" "1912410" "buildid" "25754144"')
$loaderExeOriginals = @()
foreach ($loaderExeExtension in @('pak','utoc','ucas')) {
    $loaderExeOriginalPath = Join-Path (Join-Path $loaderExeMods 'BlueprintLoader') ('BlueprintLoader_P.' + $loaderExeExtension)
    [IO.File]::WriteAllText($loaderExeOriginalPath,'original-' + $loaderExeExtension)
    $loaderExeOriginals += @{ Path=$loaderExeOriginalPath; Hash=(Get-FileHash -LiteralPath $loaderExeOriginalPath).Hash }
}
function Invoke-SetupExeCheck([string]$Operation,[bool]$ExpectedSuccess) {
    $loaderExeRun = Join-Path ([IO.Path]::GetTempPath()) ('ModLabLoader-run-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $loaderExeRun | Out-Null
    $loaderExeResultPath = Join-Path $loaderExeRun 'result.json'
    $loaderExeWorker = Start-Process -FilePath $SetupPath -ArgumentList @('--worker',$Operation,('"'+$loaderExeGame+'"'),('"'+$loaderExeResultPath+'"')) -WindowStyle Hidden -PassThru -Wait
    if (-not (Test-Path -LiteralPath $loaderExeResultPath)) { throw 'Setup worker returned no result.' }
    $loaderExeResult = Get-Content -LiteralPath $loaderExeResultPath -Raw | ConvertFrom-Json
    if ($loaderExeResult.Success -ne $ExpectedSuccess -or (($loaderExeWorker.ExitCode -eq 0) -ne $ExpectedSuccess)) { throw ('Unexpected Setup result: ' + $loaderExeResult.Details) }
    Write-Output ($Operation + ': ' + $loaderExeResult.Message)
}
Invoke-SetupExeCheck Install $true
Invoke-SetupExeCheck Install $true
Invoke-SetupExeCheck Restore $true
foreach ($loaderExeOriginal in $loaderExeOriginals) { if ((Get-FileHash -LiteralPath $loaderExeOriginal.Path).Hash -ne $loaderExeOriginal.Hash) { throw 'Compiled Setup did not restore original package.' } }
[IO.File]::WriteAllText($loaderExeManifest,'"appid" "1912410" "buildid" "999"')
Invoke-SetupExeCheck Install $false
foreach ($loaderExeOriginal in $loaderExeOriginals) { if ((Get-FileHash -LiteralPath $loaderExeOriginal.Path).Hash -ne $loaderExeOriginal.Hash) { throw 'Rejected Setup changed an original package.' } }
[IO.File]::WriteAllText($loaderExeManifest,'"appid" "1912410" "buildid" "25754144"')
$loaderExeUnusedOriginals = Join-Path $loaderExeTestRoot 'Previous-loader-not-mounted'
New-Item -ItemType Directory -Path $loaderExeUnusedOriginals | Out-Null
foreach ($loaderExeOriginal in $loaderExeOriginals) { Move-Item -LiteralPath $loaderExeOriginal.Path -Destination (Join-Path $loaderExeUnusedOriginals ([IO.Path]::GetFileName($loaderExeOriginal.Path))) }
Invoke-SetupExeCheck Install $true
Invoke-SetupExeCheck Install $true
Invoke-SetupExeCheck Restore $true
if (Test-Path -LiteralPath (Join-Path $loaderExeMods 'ModLabLoader\ModLabLoader_P.pak')) { throw 'Clean-install removal left our loader enabled.' }
foreach ($loaderExeOriginal in $loaderExeOriginals) { if (Test-Path -LiteralPath $loaderExeOriginal.Path) { throw 'Clean-install removal restored a loader that had not been installed.' } }
Write-Output ('PASS compiled Setup embedded package install/update/restore, unsupported-build rejection and clean installation without a previous loader. Evidence: ' + $loaderExeTestRoot)
