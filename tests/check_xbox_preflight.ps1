param([string]$CollectorPath = (Join-Path $PSScriptRoot '..\tools\get_xbox_installation_report.ps1'))
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ModLab-Xbox-preflight-check-' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot)
$library = Join-Path $testRoot 'XboxGames ü $ sample'
function Check([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }
function Seed-Layout([string]$FixtureGameRoot, [string]$Engine, [string]$Config, [string]$BinaryTarget = 'Win64') {
    $content = Join-Path $FixtureGameRoot 'Content'
    $paks = Join-Path $content ($Engine + '\Content\Paks')
    $binaries = Join-Path $content ($Engine + '\Binaries\' + $BinaryTarget)
    [void](New-Item -ItemType Directory -Path $paks -Force)
    [void](New-Item -ItemType Directory -Path $binaries -Force)
    [IO.File]::WriteAllText((Join-Path $paks 'global.utoc'), 'fake metadata, not a game package')
    [IO.File]::WriteAllText((Join-Path $binaries ($Engine + '-' + $BinaryTarget + '-Shipping.exe')), 'fake executable, never run')
    [IO.File]::WriteAllText((Join-Path $content 'MicrosoftGame.config'), $Config)
    [IO.File]::WriteAllText((Join-Path $FixtureGameRoot 'save-sentinel.txt'), 'keep this test sentinel')
}
$gameA = Join-Path $library 'Unknown Xbox directory name'
$gameB = Join-Path $library 'Different Store folder'
$gameInvalid = Join-Path $library 'Invalid metadata'
$goodConfig = '<Game configVersion="1"><Identity Name="TestOnly.NotARealStoreIdentity" Version="1.1.2.0"/><ExecutableList><Executable Name="Dungeons.exe" Id="Game"/></ExecutableList></Game>'
Seed-Layout $gameA 'Dungeons' $goodConfig
Seed-Layout $gameB 'Dun' '<Game><Identity Name="TestOnly.Dun" Version="9.0.0.0"/></Game>' 'WinGDK'
Seed-Layout $gameInvalid 'Dungeons' ('<!DOCTYPE Game [<!ENTITY leak SYSTEM "file:///' + (Join-Path $gameA 'save-sentinel.txt').Replace('\','/') + '">]><Game><Identity Name="&leak;"/></Game>')
[void](New-Item -ItemType Directory -Path (Join-Path $library 'Unrelated title\Content') -Force)
$before = @{}
Get-ChildItem -LiteralPath $library -File -Recurse | ForEach-Object { $before[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
$path = Join-Path $testRoot 'automatic.json'
$resultPath = & $CollectorPath -XboxLibraryRoots @($library, $library.ToUpperInvariant()) -OutputPath $path
Check ($resultPath -eq $path) 'Unexpected report destination.'
$report = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
Check ($report.CandidateCount -eq 3) 'Expected both layouts plus invalid-config candidate, without duplicate/unrelated folders.'
Check (-not $report.AbsoluteGamePathsIncluded) 'Paths included without opt-in.'
Check (-not (Get-Content -LiteralPath $path -Raw -Encoding UTF8).Contains($testRoot)) 'Absolute fixture root leaked into report.'
Check (@($report.Candidates | Where-Object { $_.EngineDirectory -eq 'Dun' }).Count -eq 1) 'Dun candidate missing.'
Check (@($report.Candidates | ForEach-Object { $_.Files } | Where-Object { $_.RelativePath -like '*\WinGDK\*' }).Count -eq 1) 'WinGDK executable candidate missing.'
Check (@($report.Candidates | Where-Object { $_.MicrosoftConfig.PackageVersion -eq '1.1.2.0' }).Count -eq 1) 'Package version misread.'
Check (@($report.Candidates | Where-Object { $_.MicrosoftConfig.Status -eq 'UnreadableOrInvalidConfig' }).Count -eq 1) 'External XML entity was not rejected.'
Check (@($report.Candidates | Where-Object { $_.InstallerCanInstallXbox -or $_.GameIdentityVerified -or $_.XboxRuntimeCompatibility -ne 'Unverified' }).Count -eq 0) 'Unverified candidate was presented as supported.'
Check (@($report.Candidates | ForEach-Object { $_.Files } | Where-Object { $_.SHA256 -notmatch '^[A-F0-9]{64}$' }).Count -eq 0) 'Missing runtime fingerprint.'
$explicit = Join-Path $testRoot 'explicit.json'
& $CollectorPath -GameDirectory (Join-Path $gameA 'Content') -OutputPath $explicit | Out-Null
$explicitReport = Get-Content -LiteralPath $explicit -Raw -Encoding UTF8 | ConvertFrom-Json
Check ($explicitReport.CandidateCount -eq 1 -and $explicitReport.Candidates[0].LayoutRelativeToSelectedFolder -eq '.') 'Explicit Content selection did not resolve the layout.'
$invalidOutput = Join-Path $gameA 'report.json'
$rejected = $false
try { & $CollectorPath -GameDirectory $gameA -OutputPath $invalidOutput | Out-Null } catch { $rejected = $true }
Check ($rejected -and -not (Test-Path -LiteralPath $invalidOutput)) 'Report wrote into the game directory.'
$rejected = $false
try { & $CollectorPath -GameDirectory (Join-Path $gameA 'Content') -OutputPath $invalidOutput | Out-Null } catch { $rejected = $true }
Check ($rejected -and -not (Test-Path -LiteralPath $invalidOutput)) 'Content selection allowed writing into its parent game directory.'
$originalOutputHash = (Get-FileHash -LiteralPath $path).Hash
$rejected = $false
try { & $CollectorPath -GameDirectory $gameA -OutputPath $path | Out-Null } catch { $rejected = $true }
Check ($rejected -and (Get-FileHash -LiteralPath $path).Hash -eq $originalOutputHash) 'Occupied report was overwritten.'
$afterFiles = @(Get-ChildItem -LiteralPath $library -File -Recurse)
Check ($afterFiles.Count -eq $before.Count) 'Game fixture gained or lost files.'
foreach ($file in $afterFiles) { Check ((Get-FileHash -LiteralPath $file.FullName).Hash -eq $before[$file.FullName]) ('Game fixture changed: ' + $file.Name) }
Write-Output ('PASS: Xbox layout preflight, metadata privacy, invalid XML, write guards, and all game files unchanged. Evidence: ' + $testRoot)
