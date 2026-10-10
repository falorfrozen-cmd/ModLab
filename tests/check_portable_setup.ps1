param(
    [Parameter(Mandatory=$true)][string]$DistributionZip,
    [Parameter(Mandatory=$true)][string]$ExpectedExecutableSHA256,
    [string]$PreviousSetupPath
)
$ErrorActionPreference = 'Stop'
$portableCheckRoot = Join-Path ([IO.Path]::GetTempPath()) ('ModLab-portable-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $portableCheckRoot | Out-Null
Expand-Archive -LiteralPath $DistributionZip -DestinationPath $portableCheckRoot
$portableCheckBundle = Join-Path $portableCheckRoot 'ModLab'
$portableCheckExe = Join-Path $portableCheckBundle 'ModLab.exe'
$portableCheckPackage = Join-Path $portableCheckBundle 'Package'
if ((Get-FileHash -LiteralPath $portableCheckExe).Hash -ne $ExpectedExecutableSHA256) { throw 'The ZIP contains a different executable.' }
$portableCheckManifestPath = Join-Path $portableCheckPackage 'ModLab.manifest.json'
$portableCheckManifest = Get-Content -LiteralPath $portableCheckManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($entry in $portableCheckManifest.Files) {
    $file = Join-Path $portableCheckPackage $entry.Name
    if ((Get-FileHash -LiteralPath $file).Hash -ne $entry.SHA256 -or (Get-Item -LiteralPath $file).Length -ne $entry.Bytes) { throw 'Extracted runtime integrity failed.' }
}
$portableCheckGame = Join-Path $portableCheckRoot 'Steam\steamapps\common\Game'
function Write-PortableFixture([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Text)
}
Write-PortableFixture (Join-Path $portableCheckGame 'Dungeons\Content\Paks\global.utoc') 'fixture'
Write-PortableFixture (Join-Path $portableCheckGame 'Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe') 'fixture'
Write-PortableFixture (Join-Path $portableCheckRoot 'Steam\steamapps\appmanifest_1912410.acf') '"appid" "1912410" "buildid" "25754144"'
$portableCheckOriginals = @(Get-ChildItem -LiteralPath $portableCheckGame -File -Recurse | ForEach-Object { @{ Path=$_.FullName; Hash=(Get-FileHash -LiteralPath $_.FullName).Hash } })
function Assert-PortableUnchanged {
    if (Test-Path -LiteralPath (Join-Path $portableCheckGame 'ModLabBackups')) { throw 'Rejected operation mutated the game directory.' }
    foreach ($original in $portableCheckOriginals) { if ((Get-FileHash -LiteralPath $original.Path).Hash -ne $original.Hash) { throw 'Rejected operation changed a game file.' } }
    if (@(Get-ChildItem -LiteralPath $portableCheckGame -File -Recurse).Count -ne $portableCheckOriginals.Count) { throw 'Rejected operation created a game file.' }
}
function Invoke-PortableRejection([string]$Label, [string]$ExpectedMessage, [switch]$Occupied) {
    $run = Join-Path $portableCheckRoot ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $run | Out-Null
    $result = Join-Path $run 'result.json'
    if ($Occupied) { [IO.File]::WriteAllText($result, 'occupied result sentinel') }
    $process = Start-Process -FilePath $portableCheckExe -ArgumentList @('--worker','Install',('"'+$portableCheckGame+'"'),('"'+$result+'"')) -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -eq 0) { throw ('Accepted invalid input: '+$Label) }
    if ($Occupied) {
        if ([IO.File]::ReadAllText($result) -ne 'occupied result sentinel') { throw 'Occupied result destination was overwritten.' }
    } else {
        $record = Get-Content -LiteralPath $result -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($record.Success -or $record.Details -notmatch $ExpectedMessage) { throw ('Wrong failure for '+$Label+': '+$record.Details) }
    }
    Assert-PortableUnchanged
    Write-Output ('PASS '+$Label)
}
Invoke-PortableRejection 'occupied result destination' '' -Occupied
$manifestBytes = [IO.File]::ReadAllBytes($portableCheckManifestPath)
try {
    [IO.File]::AppendAllText($portableCheckManifestPath, ' ')
    Invoke-PortableRejection 'altered external manifest' 'missing or changed'
    [IO.File]::Move($portableCheckManifestPath, $portableCheckManifestPath+'.missing')
    Invoke-PortableRejection 'missing external manifest' 'missing or changed'
} finally {
    [IO.File]::WriteAllBytes($portableCheckManifestPath, $manifestBytes)
}
$runtimePath = Join-Path $portableCheckPackage 'ModLab.html'
$runtimeBytes = [IO.File]::ReadAllBytes($runtimePath)
try {
    [IO.File]::AppendAllText($runtimePath, 'altered package sentinel')
    Invoke-PortableRejection 'altered runtime file' 'missing or changed|size'
} finally {
    [IO.File]::WriteAllBytes($runtimePath, $runtimeBytes)
}
& (Join-Path $PSScriptRoot 'check_modlab_setup.ps1') -SetupPath $portableCheckExe -PackageDirectory $portableCheckPackage -PreviousSetupPath $PreviousSetupPath
if ((Get-FileHash -LiteralPath $portableCheckExe).Hash -ne $ExpectedExecutableSHA256) { throw 'The tested executable changed.' }
Write-Output ('PASS complete extracted ZIP and portable integrity boundaries. Evidence: '+$portableCheckRoot)
