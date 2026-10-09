param(
    [Parameter(Mandatory=$true)][string]$PackageDirectory,
    [string]$Version = '0.1.0-alpha.3'
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[a-z0-9.]+)?$') { throw 'Invalid release version.' }
$loaderReleaseNumber = $Version.Split('-')[0]
$loaderReleaseRoot = Split-Path $PSScriptRoot -Parent
$loaderReleaseOutput = Join-Path $loaderReleaseRoot 'dist\player'
$loaderReleaseBuild = Join-Path $loaderReleaseRoot ('bin\Installer-' + [guid]::NewGuid().ToString('N'))
$loaderReleasePayload = Join-Path $loaderReleaseBuild 'Payload'
New-Item -ItemType Directory -Path $loaderReleasePayload -Force | Out-Null
New-Item -ItemType Directory -Path $loaderReleaseOutput -Force | Out-Null
$loaderReleaseManifest = Get-Content -LiteralPath (Join-Path $PackageDirectory 'ModLab.manifest.json') -Raw | ConvertFrom-Json
$loaderReleaseNames = @('ModLabLoader_P.pak','ModLabLoader_P.ucas','ModLabLoader_P.utoc','QoLSuite_P.pak','QoLSuite_P.ucas','QoLSuite_P.utoc','ModLab.html','BerserkerBuffs.png')
if ($loaderReleaseManifest.Schema -ne 1 -or $loaderReleaseManifest.Profile -ne 'ModLab' -or $loaderReleaseManifest.SteamBuild -ne 25754144 -or @($loaderReleaseManifest.Files).Count -ne 8 -or $loaderReleaseManifest.Version -ne $loaderReleaseNumber) { throw 'Unsupported runtime package or release version mismatch.' }
foreach ($loaderReleaseName in $loaderReleaseNames) {
    $loaderReleaseEntry = @($loaderReleaseManifest.Files | Where-Object Name -eq $loaderReleaseName)
    if ($loaderReleaseEntry.Count -ne 1 -or (Get-FileHash -LiteralPath (Join-Path $PackageDirectory $loaderReleaseName)).Hash -ne $loaderReleaseEntry[0].SHA256) { throw 'Runtime package verification failed.' }
    Copy-Item -LiteralPath (Join-Path $PackageDirectory $loaderReleaseName) -Destination $loaderReleasePayload
}
Copy-Item -LiteralPath (Join-Path $PackageDirectory 'ModLab.manifest.json') -Destination $loaderReleasePayload
Copy-Item -LiteralPath (Join-Path $loaderReleaseRoot 'mods\ModLabLoader\Branding\NeoRune-LICENSE.txt') -Destination $loaderReleasePayload
Copy-Item -LiteralPath (Join-Path $loaderReleaseRoot 'player-installer\LICENSE') -Destination $loaderReleasePayload
Copy-Item -LiteralPath (Join-Path $loaderReleaseRoot 'player-installer\THIRD-PARTY-NOTICES.md') -Destination $loaderReleasePayload
$loaderReleaseZip = Join-Path $loaderReleaseBuild 'Payload.zip'
Compress-Archive -Path (Join-Path $loaderReleasePayload '*') -DestinationPath $loaderReleaseZip -CompressionLevel Optimal
$loaderReleaseHash = (Get-FileHash -LiteralPath $loaderReleaseZip).Hash
$loaderReleaseIdentity = Join-Path $loaderReleaseBuild 'BuildIdentity.cs'
@"
using System.Reflection;
[assembly: AssemblyTitle("ModLab Setup")]
[assembly: AssemblyDescription("ModLab gameplay suite and integrated loader installer")]
[assembly: AssemblyCompany("falorfrozen-cmd")]
[assembly: AssemblyVersion("$loaderReleaseNumber.0")]
[assembly: AssemblyFileVersion("$loaderReleaseNumber.0")]
[assembly: AssemblyInformationalVersion("$Version")]
[assembly: System.Runtime.Versioning.TargetFramework(".NETFramework,Version=v4.8")]
namespace ModLab.Setup {
    public static class BuildIdentity {
        public const string Version = "$Version";
        public const string PayloadSha256 = "$loaderReleaseHash";
    }
}
"@ | Set-Content -LiteralPath $loaderReleaseIdentity -Encoding UTF8
$loaderReleaseCompiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $loaderReleaseCompiler)) { throw 'The Windows .NET Framework C# compiler is required to build Setup.' }
$loaderReleaseExe = Join-Path $loaderReleaseOutput ('ModLab-Setup-' + $Version + '.exe')
$loaderReleaseCompilerArgs = @('/nologo','/target:winexe','/platform:x64','/optimize+','/warn:4','/warnaserror+','/codepage:65001',
    ('/out:' + $loaderReleaseExe),('/win32manifest:' + (Join-Path $loaderReleaseRoot 'player-installer\app.manifest')),
    ('/resource:' + $loaderReleaseZip + ',ModLab.Payload.zip'),
    '/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.IO.Compression.dll',
    '/reference:System.IO.Compression.FileSystem.dll','/reference:System.Web.Extensions.dll',
    (Join-Path $loaderReleaseRoot 'player-installer\Installer.cs'),(Join-Path $loaderReleaseRoot 'player-installer\SteamDiscovery.cs'),(Join-Path $loaderReleaseRoot 'player-installer\NativeTransaction.cs'),$loaderReleaseIdentity)
& $loaderReleaseCompiler @loaderReleaseCompilerArgs
if ($LASTEXITCODE -ne 0) { throw 'Setup compilation failed.' }
$loaderReleaseMetadata = @{ Version=$Version; Executable=$loaderReleaseExe; BuildDirectory=$loaderReleaseBuild; Payload=$loaderReleaseZip; Identity=$loaderReleaseIdentity; Compiler=$loaderReleaseCompiler }
$loaderReleaseMetadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $loaderReleaseOutput 'installer-build.json') -Encoding UTF8
Write-Output ('Setup compiled: ' + $loaderReleaseExe)
