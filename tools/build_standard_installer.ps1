param(
    [Parameter(Mandatory=$true)][string]$PackageDirectory,
    [Parameter(Mandatory=$true)][string]$InnoCompiler,
    [string]$Version = '0.1.0-alpha.6',
    [string]$OutputDirectory,
    [string]$SignToolPath,
    [string]$SignCertificateThumbprint
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[a-z0-9.]+)?$') { throw 'Invalid release version.' }
$standardRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'installer_build_guard.ps1')
$standardCompiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$standardCompilerAudit = Assert-ModLabCompiler $standardCompiler 'Microsoft Corporation'
$standardInnoAudit = Assert-ModLabCompiler $InnoCompiler 'Pyrsys B.V.'
$InnoCompiler = $standardInnoAudit.Path
$standardIcon = Join-Path $standardRoot 'player-installer\ModLab.ico'
if (-not (Test-Path -LiteralPath $standardIcon -PathType Leaf)) { throw ('Setup icon is missing: ' + $standardIcon) }
# Optional code signing. Signing the worker before Inno embeds it and signing
# the compiled Setup afterwards establishes publisher identity and integrity.
# It does not guarantee antivirus acceptance or warning-free first downloads.
function Invoke-ModLabSign {
    param([string]$File)
    if (-not $SignToolPath -and -not $SignCertificateThumbprint) { return $false }
    if (-not $SignToolPath -or -not $SignCertificateThumbprint) { throw 'Provide both -SignToolPath and -SignCertificateThumbprint to sign release binaries.' }
    $tool = [IO.Path]::GetFullPath($SignToolPath)
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw ('Signing tool is missing: ' + $tool) }
    $signOutput = & $tool sign /sha1 $SignCertificateThumbprint /fd SHA256 /tr 'http://timestamp.digicert.com' /td SHA256 $File 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('Signing failed for ' + $File + ': ' + ($signOutput -join ' ')) }
    $signature = Get-AuthenticodeSignature -LiteralPath $File
    if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate) { throw ('Signature verification failed for ' + $File + ': ' + $signature.Status) }
    return $true
}
$standardOutput = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $standardRoot 'dist\player' }
Assert-ModLabBuildOutput $standardOutput $Version
$standardStage = Join-Path $standardRoot ('bin\StandardInstaller-' + [guid]::NewGuid().ToString('N'))
$standardPayload = Join-Path $standardStage 'Payload'
New-Item -ItemType Directory -Path $standardOutput -Force | Out-Null
$standardBuildLock = [IO.FileStream]::new((Join-Path $standardOutput ('.ModLab-'+$Version+'.build.lock')), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
Assert-ModLabBuildOutput $standardOutput $Version
New-Item -ItemType Directory -Path $standardPayload -Force | Out-Null
$standardManifestPath = Join-Path $PackageDirectory 'ModLab.manifest.json'
$standardManifest = Get-Content -LiteralPath $standardManifestPath -Raw | ConvertFrom-Json
$standardNames = @('ModLabLoader_P.pak','ModLabLoader_P.ucas','ModLabLoader_P.utoc','QoLSuite_P.pak','QoLSuite_P.ucas','QoLSuite_P.utoc','ModLab.html','BerserkerBuffs.png')
if ($standardManifest.Schema -ne 1 -or $standardManifest.Profile -ne 'ModLab' -or $standardManifest.SteamBuild -ne 25754144 -or @($standardManifest.Files).Count -ne 8 -or $standardManifest.Version -ne $Version.Split('-')[0]) { throw 'Unsupported runtime package.' }
foreach ($standardName in $standardNames) {
    $entry = @($standardManifest.Files | Where-Object Name -CEQ $standardName)
    $source = Join-Path $PackageDirectory $standardName
    $folder = if ($standardName.StartsWith('ModLabLoader_')) { 'ModLabLoader' } else { 'QoLSuite' }
    if ($entry.Count -ne 1 -or $entry[0].RelativePath -cne ($folder+'\'+$standardName) -or
        $entry[0].Bytes -ne (Get-Item -LiteralPath $source).Length -or (Get-FileHash -LiteralPath $source).Hash -ne $entry[0].SHA256) { throw 'Runtime verification failed.' }
    Copy-Item -LiteralPath $source -Destination $standardPayload
}
Copy-Item -LiteralPath $standardManifestPath -Destination $standardPayload
$standardManifestHash = (Get-FileHash -LiteralPath $standardManifestPath).Hash
$standardIdentity = Join-Path $standardStage 'BuildIdentity.cs'
$standardNumber = $Version.Split('-')[0]
@"
using System.Reflection;
[assembly: AssemblyTitle("ModLab Installation Worker")]
[assembly: AssemblyDescription("Verified ModLab file installation, backup and restoration")]
[assembly: AssemblyCompany("falorfrozen-cmd")]
[assembly: AssemblyProduct("ModLab")]
[assembly: AssemblyCopyright("Copyright (C) 2026 falorfrozen-cmd")]
[assembly: AssemblyConfiguration("Release")]
[assembly: AssemblyVersion("$standardNumber.0")]
[assembly: AssemblyFileVersion("$standardNumber.0")]
[assembly: AssemblyInformationalVersion("$Version")]
[assembly: System.Runtime.Versioning.TargetFramework(".NETFramework,Version=v4.8")]
namespace ModLab.Setup { public static class BuildIdentity { public const string ManifestSha256 = "$standardManifestHash"; } }
"@ | Set-Content -LiteralPath $standardIdentity -Encoding UTF8
$standardWorker = Join-Path $standardPayload 'ModLabWorker.exe'
& $standardCompiler '/nologo' '/target:winexe' '/platform:x64' '/optimize+' '/warn:4' '/warnaserror+' '/codepage:65001' ('/out:'+$standardWorker) ('/win32manifest:'+(Join-Path $standardRoot 'player-installer\app.manifest')) ('/win32icon:'+$standardIcon) '/reference:System.Web.Extensions.dll' (Join-Path $standardRoot 'player-installer\SteamDiscovery.cs') (Join-Path $standardRoot 'player-installer\NativeTransaction.cs') (Join-Path $standardRoot 'player-installer\NativeWorker.cs') $standardIdentity
if ($LASTEXITCODE -ne 0) { throw 'Native worker compilation failed.' }
$standardWorkerSigned = Invoke-ModLabSign $standardWorker
$standardNotice = [Text.StringBuilder]::new()
[void]$standardNotice.AppendLine('ModLab '+$Version).AppendLine('Minecraft Dungeons II / Steam build 25754144 / game 1.1.2.0').AppendLine()
foreach ($noticeFile in @((Join-Path $standardRoot 'player-installer\LICENSE'),(Join-Path $standardRoot 'mods\ModLabLoader\Branding\NeoRune-LICENSE.txt'),(Join-Path $standardRoot 'player-installer\THIRD-PARTY-NOTICES.md'))) {
    [void]$standardNotice.AppendLine([IO.Path]::GetFileName($noticeFile)).AppendLine([IO.File]::ReadAllText($noticeFile)).AppendLine()
}
$standardInnoLicense = Join-Path (Split-Path $InnoCompiler -Parent) 'License.txt'
if (-not (Test-Path -LiteralPath $standardInnoLicense)) { throw 'Compiler license file is missing.' }
[void]$standardNotice.AppendLine('Inno Setup license').AppendLine([IO.File]::ReadAllText($standardInnoLicense))
[IO.File]::WriteAllText((Join-Path $standardPayload 'NOTICES.txt'),$standardNotice.ToString(),[Text.UTF8Encoding]::new($true))
& $InnoCompiler '/Qp' ('/DModLabVersion='+$Version) ('/DPayloadDir='+$standardPayload) ('/DOutputDir='+$standardOutput) ('/DSetupIconFile='+$standardIcon) (Join-Path $standardRoot 'player-installer\ModLab.iss')
if ($LASTEXITCODE -ne 0) { throw 'Standard Setup compilation failed.' }
$standardExe = Join-Path $standardOutput ('ModLab-Setup-'+$Version+'.exe')
$standardExeSigned = Invoke-ModLabSign $standardExe
$standardSigner = if ($standardExeSigned) { (Get-AuthenticodeSignature -LiteralPath $standardExe).SignerCertificate.Subject } else { $null }
$standardBuildRecord = @{ Kind='Standard'; Version=$Version; Executable=$standardExe; BuildDirectory=$standardStage; PayloadDirectory=$standardPayload; Identity=$standardIdentity; Compiler=$standardCompiler; InnoCompiler=$InnoCompiler; CompilerAudit=$standardCompilerAudit; InnoCompilerAudit=$standardInnoAudit; Icon=$standardIcon; IconSHA256=(Get-FileHash -LiteralPath $standardIcon).Hash; Signed=$standardExeSigned; WorkerSigned=$standardWorkerSigned; SignerCertificate=$standardSigner; ManifestSHA256=$standardManifestHash; WorkerSHA256=(Get-FileHash -LiteralPath $standardWorker).Hash; SHA256=(Get-FileHash -LiteralPath $standardExe).Hash } | ConvertTo-Json -Depth 4
$standardBuildRecord | Set-Content -LiteralPath (Join-Path $standardOutput ('standard-installer-build-'+$Version+'.json')) -Encoding UTF8
$standardBuildRecord | Set-Content -LiteralPath (Join-Path $standardOutput 'standard-installer-build.json') -Encoding UTF8
Write-Output ('Standard Setup compiled: '+$standardExe)
} finally { $standardBuildLock.Dispose() }
