param(
    [Parameter(Mandatory=$true)][string]$PackageDirectory,
    [string]$Version = '0.1.0-alpha.7',
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[a-z0-9.]+)?$') { throw 'Invalid release version.' }
$portableRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'installer_build_guard.ps1')
$portableCompiler = Assert-ModLabCompiler (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe') 'Microsoft Corporation'
$portableOutput = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $portableOutput) { throw 'Preserve existing artifacts; use a new isolated output directory.' }
$portableStage = Join-Path $portableRoot ('bin\PortableInstaller-'+[guid]::NewGuid().ToString('N'))
$portableBundle = Join-Path $portableOutput 'ModLab'
$portablePackage = Join-Path $portableBundle 'Package'
New-Item -ItemType Directory -Path $portableStage,$portablePackage -Force | Out-Null
$portableManifestPath = Join-Path $PackageDirectory 'ModLab.manifest.json'
$portableManifest = Get-Content -LiteralPath $portableManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$portableNames = @('ModLabLoader_P.pak','ModLabLoader_P.ucas','ModLabLoader_P.utoc','QoLSuite_P.pak','QoLSuite_P.ucas','QoLSuite_P.utoc','ModLab.html','BerserkerBuffs.png')
if ($portableManifest.Schema -ne 1 -or $portableManifest.Profile -ne 'ModLab' -or $portableManifest.SteamBuild -ne 25754144 -or @($portableManifest.Files).Count -ne 8 -or $portableManifest.Version -ne $Version.Split('-')[0]) { throw 'Unsupported runtime package.' }
foreach ($portableName in $portableNames) {
    $portableEntry = @($portableManifest.Files | Where-Object Name -CEQ $portableName)
    $portableSource = Join-Path $PackageDirectory $portableName
    $portableFolder = if ($portableName.StartsWith('ModLabLoader_')) { 'ModLabLoader' } else { 'QoLSuite' }
    if ($portableEntry.Count -ne 1 -or $portableEntry[0].RelativePath -cne ($portableFolder+'\'+$portableName) -or
        $portableEntry[0].Bytes -ne (Get-Item -LiteralPath $portableSource).Length -or (Get-FileHash -LiteralPath $portableSource).Hash -ne $portableEntry[0].SHA256) { throw 'Runtime package verification failed.' }
    Copy-Item -LiteralPath $portableSource -Destination $portablePackage
}
Copy-Item -LiteralPath $portableManifestPath -Destination $portablePackage
$portableHash = (Get-FileHash -LiteralPath $portableManifestPath).Hash
$portableIdentity = Join-Path $portableStage 'BuildIdentity.cs'
$portableNumber = $Version.Split('-')[0]
@"
using System.Reflection;
[assembly: AssemblyTitle("ModLab Setup")]
[assembly: AssemblyDescription("Verified ModLab installation, backup and restoration")]
[assembly: AssemblyCompany("falorfrozen-cmd")]
[assembly: AssemblyProduct("ModLab")]
[assembly: AssemblyCopyright("Copyright (C) 2026 falorfrozen-cmd")]
[assembly: AssemblyVersion("$portableNumber.0")]
[assembly: AssemblyFileVersion("$portableNumber.0")]
[assembly: AssemblyInformationalVersion("$Version")]
[assembly: System.Runtime.Versioning.TargetFramework(".NETFramework,Version=v4.8")]
namespace ModLab.Setup { public static class BuildIdentity { public const string Version = "$Version"; public const string ManifestSha256 = "$portableHash"; } }
"@ | Set-Content -LiteralPath $portableIdentity -Encoding UTF8
$portableExe = Join-Path $portableBundle 'ModLab.exe'
& $portableCompiler.Path '/nologo' '/target:winexe' '/platform:x64' '/optimize+' '/warn:4' '/warnaserror+' '/codepage:65001' ('/out:'+$portableExe) ('/win32manifest:'+(Join-Path $portableRoot 'player-installer\app.manifest')) ('/win32icon:'+(Join-Path $portableRoot 'player-installer\ModLab.ico')) '/reference:System.Web.Extensions.dll' '/reference:System.Windows.Forms.dll' '/reference:System.Drawing.dll' (Join-Path $portableRoot 'player-installer\SteamDiscovery.cs') (Join-Path $portableRoot 'player-installer\NativeTransaction.cs') (Join-Path $portableRoot 'player-installer\PortableSetup.cs') $portableIdentity
if ($LASTEXITCODE -ne 0) { throw 'Portable Setup compilation failed.' }
foreach ($portableNotice in @((Join-Path $portableRoot 'player-installer\LICENSE'),(Join-Path $portableRoot 'mods\ModLabLoader\Branding\NeoRune-LICENSE.txt'),(Join-Path $portableRoot 'player-installer\THIRD-PARTY-NOTICES.md'),(Join-Path $portableRoot 'player-installer\PORTABLE-README.md'))) {
    Copy-Item -LiteralPath $portableNotice -Destination $portableBundle
}
$portableBuild = [ordered]@{ Kind='Portable'; Version=$Version; Executable=$portableExe; PayloadDirectory=$portablePackage; BuildDirectory=$portableStage; Identity=$portableIdentity; Compiler=$portableCompiler; ManifestSHA256=$portableHash; SHA256=(Get-FileHash -LiteralPath $portableExe).Hash; Signed=$false; EmbeddedRuntimeArchive=$false; ExtractedExecutable=$false; RuntimeFiles=$portableManifest.Files }
$portableBuild | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $portableOutput 'portable-installer-build.json') -Encoding UTF8
$portableZip = Join-Path $portableOutput ('ModLab-'+$Version+'-Portable-Setup.zip')
Compress-Archive -LiteralPath $portableBundle -DestinationPath $portableZip -CompressionLevel Optimal
@((Get-FileHash -LiteralPath $portableExe).Hash+'  ModLab/ModLab.exe',(Get-FileHash -LiteralPath $portableZip).Hash+'  '+[IO.Path]::GetFileName($portableZip)) | Set-Content -LiteralPath (Join-Path $portableOutput 'SHA256SUMS.txt') -Encoding ASCII
Write-Output ('Portable Setup compiled: '+$portableExe)
Write-Output ('Complete distribution: '+$portableZip)
