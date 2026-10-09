param(
    [Parameter(Mandatory=$true)][string]$PackageDirectory,
    [string]$Version = '0.1.0-alpha.2'
)
$ErrorActionPreference = 'Stop'
$loaderBundleRepo = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'build_installer.ps1') -PackageDirectory $PackageDirectory -Version $Version
$loaderBundleOutput = Join-Path $loaderBundleRepo 'dist'
$loaderBundleBuild = Join-Path $loaderBundleRepo ('bin\Release-' + [guid]::NewGuid().ToString('N'))
$loaderManualStage = Join-Path $loaderBundleBuild 'Manual'
$loaderManualPackage = Join-Path $loaderManualStage 'ModLabLoader'
$loaderNexusStage = Join-Path $loaderBundleBuild 'Nexus'
New-Item -ItemType Directory -Path $loaderManualPackage -Force | Out-Null
New-Item -ItemType Directory -Path $loaderNexusStage -Force | Out-Null
foreach ($loaderBundleName in @('ModLabLoader_P.pak','ModLabLoader_P.utoc','ModLabLoader_P.ucas','ModLabLoader.manifest.json')) {
    Copy-Item -LiteralPath (Join-Path $PackageDirectory $loaderBundleName) -Destination $loaderManualPackage
}
Copy-Item -LiteralPath (Join-Path $loaderBundleRepo 'mods\ModLabLoader\Branding\NeoRune-LICENSE.txt') -Destination $loaderManualPackage
foreach ($loaderBundleDoc in @('README.md','LICENSE','THIRD-PARTY-NOTICES.md')) {
    # This legacy tool packages the developer bootstrap only, so use its
    # technical documentation rather than the complete-player landing page.
    $loaderBundleSource = Join-Path $loaderBundleRepo $loaderBundleDoc
    if ($loaderBundleDoc -eq 'README.md') { $loaderBundleSource = Join-Path $loaderBundleRepo 'docs\BOOTSTRAP.md' }
    Copy-Item -LiteralPath $loaderBundleSource -Destination (Join-Path $loaderManualStage $loaderBundleDoc)
    Copy-Item -LiteralPath $loaderBundleSource -Destination (Join-Path $loaderNexusStage $loaderBundleDoc)
    if ($loaderBundleDoc -ne 'LICENSE') {
        $loaderBundleText = Get-Content -LiteralPath $loaderBundleSource -Raw
        $loaderBundleText.Replace('mods/ModLabLoader/Branding/NeoRune-LICENSE.txt','ModLabLoader/NeoRune-LICENSE.txt') |
            Set-Content -LiteralPath (Join-Path $loaderManualStage $loaderBundleDoc) -Encoding UTF8
        $loaderBundleText.Replace('mods/ModLabLoader/Branding/NeoRune-LICENSE.txt','NeoRune-LICENSE.txt') |
            Set-Content -LiteralPath (Join-Path $loaderNexusStage $loaderBundleDoc) -Encoding UTF8
    }
}
New-Item -ItemType Directory -Path (Join-Path $loaderManualStage 'docs') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $loaderNexusStage 'docs') | Out-Null
foreach ($loaderBundleDoc in @('RUNTIME-VALIDATION.md','INSTALLER-VALIDATION.md','NEXUS-DESCRIPTION.md','RELEASE-NOTES.md','BUILDING.md')) {
    $loaderBundleSource = Join-Path $loaderBundleRepo ('docs\' + $loaderBundleDoc)
    if ($loaderBundleDoc -eq 'NEXUS-DESCRIPTION.md') { $loaderBundleSource = Join-Path $loaderBundleRepo 'docs\BOOTSTRAP.md' }
    Copy-Item -LiteralPath $loaderBundleSource -Destination (Join-Path $loaderManualStage ('docs\' + $loaderBundleDoc))
    Copy-Item -LiteralPath $loaderBundleSource -Destination (Join-Path $loaderNexusStage ('docs\' + $loaderBundleDoc))
}
Copy-Item -LiteralPath (Join-Path $loaderBundleRepo 'docs\assets') -Destination (Join-Path $loaderManualStage 'docs') -Recurse
Copy-Item -LiteralPath (Join-Path $loaderBundleRepo 'docs\assets') -Destination (Join-Path $loaderNexusStage 'docs') -Recurse
$loaderManualZip = Join-Path $loaderBundleOutput ('ModLabLoader-Manual-' + $Version + '.zip')
Compress-Archive -Path (Join-Path $loaderManualStage '*') -DestinationPath $loaderManualZip -CompressionLevel Optimal -Force
$loaderBundleExe = Join-Path $loaderBundleOutput ('ModLabLoader-Setup-' + $Version + '.exe')
Copy-Item -LiteralPath $loaderBundleExe -Destination $loaderNexusStage
Copy-Item -LiteralPath $loaderManualZip -Destination $loaderNexusStage
Copy-Item -LiteralPath (Join-Path $loaderManualPackage 'NeoRune-LICENSE.txt') -Destination $loaderNexusStage
# Include a checksum list for the nested downloads without a circular ZIP hash.
$loaderNestedHashes = @($loaderBundleExe,$loaderManualZip) | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash + '  ' + [IO.Path]::GetFileName($_) }
$loaderNestedHashes | Set-Content -LiteralPath (Join-Path $loaderNexusStage 'SHA256SUMS.txt') -Encoding ASCII
$loaderNexusZip = Join-Path $loaderBundleOutput ('ModLabLoader-Nexus-' + $Version + '.zip')
Compress-Archive -Path (Join-Path $loaderNexusStage '*') -DestinationPath $loaderNexusZip -CompressionLevel Optimal -Force
@($loaderBundleExe,$loaderManualZip,$loaderNexusZip) | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash + '  ' + [IO.Path]::GetFileName($_) } |
    Set-Content -LiteralPath (Join-Path $loaderBundleOutput 'SHA256SUMS.txt') -Encoding ASCII
Write-Output ('Release files prepared in ' + $loaderBundleOutput)
