param([Parameter(Mandatory=$true)][string]$PackageDirectory,[string]$Version = '0.1.0-alpha.3')
$ErrorActionPreference = 'Stop'
$checkRepo = Split-Path $PSScriptRoot -Parent
& (Join-Path $checkRepo 'tools\build_player_installer.ps1') -PackageDirectory $PackageDirectory -Version $Version
$checkBuild = Get-Content -LiteralPath (Join-Path $checkRepo 'dist\player\installer-build.json') -Raw | ConvertFrom-Json
$checkBinary = Join-Path $checkBuild.BuildDirectory 'InstallerChecks.exe'
& $checkBuild.Compiler '/nologo' '/target:exe' '/platform:x64' '/optimize+' '/warnaserror+' '/codepage:65001' ('/out:' + $checkBinary) '/main:InstallerChecks' ('/resource:' + $checkBuild.Payload + ',ModLab.Payload.zip') '/reference:System.Windows.Forms.dll' '/reference:System.Drawing.dll' '/reference:System.IO.Compression.dll' '/reference:System.IO.Compression.FileSystem.dll' '/reference:System.Web.Extensions.dll' (Join-Path $checkRepo 'player-installer\Installer.cs') (Join-Path $checkRepo 'player-installer\SteamDiscovery.cs') (Join-Path $checkRepo 'player-installer\NativeTransaction.cs') (Join-Path $PSScriptRoot 'ModLabInstallerChecks.cs') $checkBuild.Identity
if ($LASTEXITCODE -ne 0) { throw 'Installer checks did not compile.' }
& $checkBinary (Join-Path ([IO.Path]::GetTempPath()) ('ML-detect-' + [guid]::NewGuid().ToString('N').Substring(0,12))) $PackageDirectory
if ($LASTEXITCODE -ne 0) { throw 'Detection checks failed.' }
& (Join-Path $PSScriptRoot 'check_modlab_setup.ps1') -SetupPath $checkBuild.Executable -PackageDirectory $PackageDirectory
Write-Output 'PASS all combined installer checks.'
