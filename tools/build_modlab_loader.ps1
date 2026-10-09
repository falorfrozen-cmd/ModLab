param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [string]$AesKey = $env:MODLAB_GAME_AES_KEY,
    [string]$SdkRoot = (Join-Path $PSScriptRoot 'neorune-build25754144')
)
$ErrorActionPreference = 'Stop'
$loaderRoot = Split-Path $PSScriptRoot -Parent
$SdkRoot = [IO.Path]::GetFullPath($SdkRoot).TrimEnd('\','/') + '\'
$loaderSdkTools = Join-Path $SdkRoot 'tools'
$loaderDotnet = Join-Path $PSScriptRoot 'neorune-dotnet\dotnet.exe'
if (-not (Test-Path -LiteralPath $loaderDotnet)) { $loaderDotnet = (Get-Command dotnet).Source }
$loaderGamePaks = Join-Path $GameDirectory 'Dungeons\Content\Paks'
$loaderBuildDir = Join-Path $loaderRoot ('mods\ModLabLoader\bin\Hook-' + [guid]::NewGuid().ToString('N'))
$loaderPakDir = Join-Path $loaderRoot 'mods\ModLabLoader\bin\NeoRune\Pak'
$loaderStageDir = Join-Path $loaderBuildDir 'Stage'
$loaderHeaderDir = Join-Path $loaderBuildDir 'Header'
$loaderOriginalDir = Join-Path $loaderBuildDir 'Original'
$loaderCompilerDir = Join-Path $loaderBuildDir 'Compiler'
$loaderVerifiedPakDir = Join-Path $loaderBuildDir 'VerifiedPak'
$loaderFeatureRelative = 'Dungeons\Plugins\GameFeatures\R1\Content\R1.uasset'
$loaderRetoc = Join-Path $loaderSdkTools 'retoc.exe'
$loaderRepak = Join-Path $loaderSdkTools 'repak.exe'
function Invoke-LoaderTool([string]$Executable, [string[]]$ToolArguments) {
    & $Executable @ToolArguments
    if ($LASTEXITCODE -ne 0) { throw "Loader build tool failed: $Executable ($LASTEXITCODE)" }
}
if (-not (Test-Path -LiteralPath (Join-Path $loaderGamePaks 'global.utoc'))) { throw 'Select a game folder containing Dungeons\Content\Paks\global.utoc.' }
# This adapter was validated against the extracted feature layout of this build.
# Never overwrite the game's original packages: the output is a separate mod overlay.
if ([string]::IsNullOrWhiteSpace($AesKey)) {
    $AesKey = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Dokucraft/Dungeons-II-Mod-Kit/main/Internal/aes_key.txt').Content.Trim()
}
if ($AesKey -notmatch '^(0x)?[0-9a-fA-F]{64}$') { throw 'Invalid game asset key format.' }
New-Item -ItemType Directory -Path $loaderBuildDir -Force | Out-Null
Invoke-LoaderTool $loaderDotnet @('build', (Join-Path $loaderRoot 'mods\ModLabLoader\ModLabLoader.csproj'), '-p:NeoRuneInstall=false', ('-p:NeoRuneSdkRoot=' + $SdkRoot), ('-p:NeoRuneOutDir=' + $loaderCompilerDir + '\'))
# retoc also needs global.utoc's script-object table. The adapter verifies the
# original asset's fingerprint so an overlay cannot silently become our input.
Invoke-LoaderTool $loaderRetoc @('-a', $AesKey, 'to-legacy', $loaderGamePaks, $loaderOriginalDir, '--filter', '/R1.', '--no-shaders', '--version', 'UE5_6')
Copy-Item -LiteralPath (Join-Path $loaderCompilerDir 'Temp\Staging') -Destination $loaderStageDir -Recurse
Copy-Item -LiteralPath (Join-Path $loaderCompilerDir 'Temp\Header') -Destination $loaderHeaderDir -Recurse
Copy-Item -LiteralPath (Join-Path $loaderOriginalDir 'scriptobjects.bin') -Destination (Join-Path $loaderStageDir 'scriptobjects.bin')
Invoke-LoaderTool $loaderDotnet @('run', '--project', (Join-Path $PSScriptRoot 'ModLabLoaderBuild\ModLabLoaderBuild.csproj'), ('-p:LoaderToolRoot=' + $loaderSdkTools), '--', (Join-Path $loaderOriginalDir $loaderFeatureRelative), (Join-Path $loaderStageDir $loaderFeatureRelative))
$loaderHeaderFeature = Join-Path $loaderHeaderDir $loaderFeatureRelative
New-Item -ItemType Directory -Path (Split-Path $loaderHeaderFeature -Parent) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $loaderStageDir $loaderFeatureRelative) -Destination $loaderHeaderFeature
New-Item -ItemType Directory -Path $loaderVerifiedPakDir | Out-Null
Invoke-LoaderTool $loaderRetoc @('to-zen', $loaderStageDir, (Join-Path $loaderVerifiedPakDir 'ModLabLoader_P.utoc'), '--version', 'UE5_6')
Invoke-LoaderTool $loaderRepak @('pack', $loaderHeaderDir, (Join-Path $loaderVerifiedPakDir 'ModLabLoader_P.pak'), '--version', 'V11')
Invoke-LoaderTool $loaderRetoc @('verify', (Join-Path $loaderVerifiedPakDir 'ModLabLoader_P.utoc'))
$loaderPackageFiles = @(Get-ChildItem -LiteralPath $loaderVerifiedPakDir -File | Where-Object Extension -in @('.pak','.utoc','.ucas') | ForEach-Object {
    [pscustomobject]@{ Name=$_.Name; Bytes=$_.Length; SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash }
})
$loaderPackageManifest = @{ Schema=1; Version='0.1.0'; SteamBuild=25754144; Files=$loaderPackageFiles }
$loaderPackageManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $loaderVerifiedPakDir 'ModLabLoader.manifest.json') -Encoding utf8
$loaderPackageManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $loaderBuildDir 'package.json') -Encoding utf8
# Publish the directory only after all three files verify. Preserve the previous
# package beside the build evidence, and roll back if the final rename fails.
$loaderOwnedBin = [System.IO.Path]::GetFullPath((Join-Path $loaderRoot 'mods\ModLabLoader\bin')) + [System.IO.Path]::DirectorySeparatorChar
foreach ($loaderMovePath in @($loaderPakDir,$loaderVerifiedPakDir,$loaderBuildDir)) {
    if (-not [System.IO.Path]::GetFullPath($loaderMovePath).StartsWith($loaderOwnedBin,[System.StringComparison]::OrdinalIgnoreCase)) { throw 'Package publication paths must remain in the loader build directory.' }
}
$loaderPreviousPakDir = Join-Path $loaderBuildDir 'PreviousPak'
New-Item -ItemType Directory -Path (Split-Path $loaderPakDir -Parent) -Force | Out-Null
if (Test-Path -LiteralPath $loaderPakDir) { Move-Item -LiteralPath $loaderPakDir -Destination $loaderPreviousPakDir }
try { Move-Item -LiteralPath $loaderVerifiedPakDir -Destination $loaderPakDir }
catch {
    if (Test-Path -LiteralPath $loaderPreviousPakDir) { Move-Item -LiteralPath $loaderPreviousPakDir -Destination $loaderPakDir }
    throw
}
Write-Output "Loader built without installation. Evidence: $loaderBuildDir"
