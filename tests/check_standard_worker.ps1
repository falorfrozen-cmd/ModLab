param([Parameter(Mandatory=$true)][string]$BuildMetadata)
$ErrorActionPreference = 'Stop'
$workerBuild = Get-Content -LiteralPath $BuildMetadata -Raw | ConvertFrom-Json
$workerRoot = Join-Path ([IO.Path]::GetTempPath()) ('ModLab-worker-check-' + [guid]::NewGuid().ToString('N'))
$workerPayload = Join-Path $workerRoot 'Payload'
New-Item -ItemType Directory -Path $workerPayload -Force | Out-Null
foreach ($workerFile in @('ModLabWorker.exe','ModLab.manifest.json','ModLabLoader_P.pak','ModLabLoader_P.ucas','ModLabLoader_P.utoc','QoLSuite_P.pak','QoLSuite_P.ucas','QoLSuite_P.utoc','ModLab.html','BerserkerBuffs.png')) {
    Copy-Item -LiteralPath (Join-Path $workerBuild.PayloadDirectory $workerFile) -Destination $workerPayload
}
$workerGame = Join-Path $workerRoot 'Steam\steamapps\common\Game'
foreach ($fixtureRelative in @('Dungeons\Content\Paks\global.utoc','Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe')) {
    $fixturePath = Join-Path $workerGame $fixtureRelative
    New-Item -ItemType Directory -Path (Split-Path $fixturePath -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($fixturePath,'fixture')
}
[IO.File]::WriteAllText((Join-Path $workerRoot 'Steam\steamapps\appmanifest_1912410.acf'),'"appid" "1912410" "buildid" "25754144"')
$workerResult = Join-Path $workerPayload 'ModLab-result.txt'
$workerExecutable = Join-Path $workerPayload 'ModLabWorker.exe'
[IO.File]::WriteAllText($workerResult,'occupied result sentinel')
$workerProcess = Start-Process -FilePath $workerExecutable -ArgumentList @('Install',('"'+$workerGame+'"')) -WindowStyle Hidden -PassThru -Wait
if ($workerProcess.ExitCode -eq 0 -or [IO.File]::ReadAllText($workerResult) -ne 'occupied result sentinel' -or (Test-Path -LiteralPath (Join-Path $workerGame 'ModLabBackups'))) { throw 'Occupied result path was not rejected before changes.' }
Remove-Item -LiteralPath $workerResult
[IO.File]::AppendAllText((Join-Path $workerPayload 'ModLab.manifest.json'),' ')
$workerProcess = Start-Process -FilePath $workerExecutable -ArgumentList @('Install',('"'+$workerGame+'"')) -WindowStyle Hidden -PassThru -Wait
if ($workerProcess.ExitCode -eq 0 -or (Test-Path -LiteralPath (Join-Path $workerGame 'ModLabBackups'))) { throw 'Altered embedded manifest was not rejected before changes.' }
$workerResultText = [IO.File]::ReadAllText($workerResult)
if (-not $workerResultText.StartsWith('ERROR') -or $workerResultText -notmatch 'missing or changed') { throw 'Worker did not report integrity failure.' }
Write-Output ('PASS standard worker: occupied result path and altered manifest rejected before any game mutation. Evidence: '+$workerRoot)

# Exercise the same Temp-prefix comparison through an actual 8.3 executable
# path. Process-local TEMP/TMP avoid modifying the developer's environment.
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
using System.Text;
public static class ModLabShortPathFixture {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern uint GetShortPathName(string longPath, StringBuilder shortPath, uint capacity);
}
'@
$aliasRoot = Join-Path $workerRoot 'Long temporary path alias fixture'
$aliasPayload = Join-Path $aliasRoot 'Payload'
New-Item -ItemType Directory -Path $aliasPayload -Force | Out-Null
Copy-Item -LiteralPath $workerExecutable -Destination $aliasPayload
$aliasBuffer = [Text.StringBuilder]::new(32768)
$aliasLength = [ModLabShortPathFixture]::GetShortPathName($aliasPayload,$aliasBuffer,[uint32]$aliasBuffer.Capacity)
if ($aliasLength -eq 0 -or $aliasLength -ge $aliasBuffer.Capacity) { throw 'Could not resolve the alias test path.' }
$aliasStart = [Diagnostics.ProcessStartInfo]::new()
$aliasStart.FileName = Join-Path $aliasBuffer.ToString() 'ModLabWorker.exe'
$aliasStart.Arguments = '--discover'
$aliasStart.UseShellExecute = $false
$aliasStart.CreateNoWindow = $true
$aliasStart.EnvironmentVariables['TEMP'] = $aliasRoot
$aliasStart.EnvironmentVariables['TMP'] = $aliasRoot
$aliasProcess = [Diagnostics.Process]::Start($aliasStart)
try {
    if (-not $aliasProcess.WaitForExit(30000)) { $aliasProcess.Kill(); throw 'Alias worker timed out.' }
    if ($aliasProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $aliasPayload 'ModLab-games.txt'))) { throw 'Worker rejected its own Temp directory through an alias.' }
} finally { $aliasProcess.Dispose() }
if ($aliasBuffer.ToString() -ieq $aliasPayload) { Write-Output 'PASS Temp override; this volume did not expose an 8.3 alias.' }
else { Write-Output 'PASS actual worker discovery through an 8.3 path alias.' }
