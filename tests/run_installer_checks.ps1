param([Parameter(Mandatory=$true)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
$loaderCheckRepo = Split-Path $PSScriptRoot -Parent
& (Join-Path $loaderCheckRepo 'tools\build_installer.ps1') -PackageDirectory $PackageDirectory
$loaderCheckBuild = Get-Content -LiteralPath (Join-Path $loaderCheckRepo 'dist\installer-build.json') -Raw | ConvertFrom-Json
$loaderCheckBinary = Join-Path $loaderCheckBuild.BuildDirectory 'InstallerChecks.exe'
& $loaderCheckBuild.Compiler '/nologo' '/target:exe' '/platform:x64' '/optimize+' '/warnaserror+' '/codepage:65001' ('/out:' + $loaderCheckBinary) '/main:InstallerChecks' ('/resource:' + $loaderCheckBuild.Payload + ',ModLabLoader.Payload.zip') '/reference:System.Windows.Forms.dll' '/reference:System.Drawing.dll' '/reference:System.IO.Compression.dll' '/reference:System.IO.Compression.FileSystem.dll' '/reference:System.Web.Extensions.dll' (Join-Path $loaderCheckRepo 'installer\Installer.cs') (Join-Path $loaderCheckRepo 'tests\InstallerChecks.cs') $loaderCheckBuild.Identity
if ($LASTEXITCODE -ne 0) { throw 'Installer check compilation failed.' }
$loaderCheckFixtures = Join-Path ([IO.Path]::GetTempPath()) ('ML-detect-' + [guid]::NewGuid().ToString('N').Substring(0,12))
& $loaderCheckBinary $loaderCheckFixtures
if ($LASTEXITCODE -ne 0) { throw 'Installer detection checks failed.' }
& (Join-Path $PSScriptRoot 'check_modlab_loader_install.ps1') -PackageDirectory $PackageDirectory
& (Join-Path $PSScriptRoot 'check_setup_exe.ps1') -SetupPath $loaderCheckBuild.Executable
Write-Output 'PASS all installer checks.'
