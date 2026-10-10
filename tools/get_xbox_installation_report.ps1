[CmdletBinding()]
param(
    [string]$GameDirectory,
    [string[]]$XboxLibraryRoots,
    [string]$OutputPath = (Join-Path ([IO.Path]::GetTempPath()) ('ModLab-Xbox-Report-' + [Guid]::NewGuid().ToString('N') + '.json')),
    [switch]$IncludePaths
)
$ErrorActionPreference = 'Stop'

# Read-only preflight for an unverified platform. This is NOT an installer.
# It never changes game files, permissions, mod packages, saves, or services.
# Only a new report file is written, outside every inspected game/library root.
function Get-NormalPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathRooted($Path)) {
        throw 'Use an absolute folder or output path.'
    }
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -eq [IO.Path]::GetPathRoot($full)) { return $full }
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
}
function Test-PlainPath([string]$Path) {
    for ($check = $Path; -not [string]::IsNullOrEmpty($check); $check = [IO.Path]::GetDirectoryName($check)) {
        if ($check -match '(?i)(^|\\)WindowsApps(\\|$)') { return $false }
        if ([IO.File]::Exists($check) -or [IO.Directory]::Exists($check)) {
            if (([IO.File]::GetAttributes($check) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
        }
    }
    return $true
}
function Get-ConfigSummary([string]$Path) {
    if (-not [IO.File]::Exists($Path)) { return $null }
    if (-not (Test-PlainPath $Path)) { return [ordered]@{ Status='SkippedReparsePath' } }
    if ((Get-Item -LiteralPath $Path).Length -gt 1048576) { return [ordered]@{ Status='ConfigTooLarge' } }
    $reader = $null
    try {
        $settings = New-Object System.Xml.XmlReaderSettings
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $settings.MaxCharactersInDocument = 1048576
        $reader = [System.Xml.XmlReader]::Create($Path, $settings)
        $document = New-Object System.Xml.XmlDocument
        $document.XmlResolver = $null
        $document.Load($reader)
        $identity = $document.SelectSingleNode("/*[local-name()='Game']/*[local-name()='Identity']")
        $executables = @($document.SelectNodes("/*[local-name()='Game']/*[local-name()='ExecutableList']/*[local-name()='Executable']") | ForEach-Object { $_.GetAttribute('Name') })
        if ($null -eq $identity) { return [ordered]@{ Status='MissingIdentity' } }
        return [ordered]@{ Status='Read'; IdentityName=$identity.GetAttribute('Name'); PackageVersion=$identity.GetAttribute('Version'); ExecutableNames=$executables }
    } catch {
        return [ordered]@{ Status='UnreadableOrInvalidConfig' }
    } finally { if ($null -ne $reader) { $reader.Dispose() } }
}
function Get-Fingerprint([string]$Path, [string]$RelativePath, [switch]$Version) {
    if (-not [IO.File]::Exists($Path)) { return [ordered]@{ RelativePath=$RelativePath; Status='Missing' } }
    if (-not (Test-PlainPath $Path)) { return [ordered]@{ RelativePath=$RelativePath; Status='SkippedReparsePath' } }
    $record = [ordered]@{ RelativePath=$RelativePath; Status='Read'; Bytes=(Get-Item -LiteralPath $Path).Length; SHA256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
    if ($Version) {
        $info = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
        $record.FileVersion = $info.FileVersion
        $record.ProductVersion = $info.ProductVersion
        $record.ProductName = $info.ProductName
    }
    return $record
}

$candidateFolders = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$inspectedRoots = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$warnings = New-Object 'System.Collections.Generic.List[string]'
if (-not [string]::IsNullOrWhiteSpace($GameDirectory)) {
    $selected = Get-NormalPath $GameDirectory
    if (-not [IO.Directory]::Exists($selected) -or -not (Test-PlainPath $selected)) { throw 'Select an existing flat-file game folder, without WindowsApps or junctions.' }
    [void]$candidateFolders.Add($selected)
    [void]$inspectedRoots.Add($selected)
    if ([IO.Path]::GetFileName($selected).Equals('Content', [StringComparison]::OrdinalIgnoreCase)) {
        # Content belongs to the surrounding Xbox game folder. Neither is an
        # acceptable report destination, even when Content was selected alone.
        [void]$inspectedRoots.Add([IO.Path]::GetDirectoryName($selected))
    }
} else {
    $roots = @($XboxLibraryRoots)
    if ($roots.Count -eq 0) {
        $roots = @([IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq [IO.DriveType]::Fixed -and $_.IsReady } | ForEach-Object { Join-Path $_.RootDirectory.FullName 'XboxGames' })
    }
    foreach ($rootInput in $roots) {
        try {
            $library = Get-NormalPath $rootInput
            if (-not [IO.Directory]::Exists($library) -or -not (Test-PlainPath $library)) { continue }
            [void]$inspectedRoots.Add($library)
            # One directory level only. No recursive disk or WindowsApps scan.
            foreach ($folder in [IO.Directory]::EnumerateDirectories($library)) {
                if (Test-PlainPath $folder) { [void]$candidateFolders.Add($folder) }
            }
        } catch { [void]$warnings.Add('A library could not be read. Select the game folder explicitly.') }
    }
}
$destination = Get-NormalPath $OutputPath
if (-not (Test-PlainPath $destination) -or -not [IO.Directory]::Exists([IO.Path]::GetDirectoryName($destination))) { throw 'The report needs an existing output folder without junctions.' }
if ([IO.File]::Exists($destination) -or [IO.Directory]::Exists($destination)) { throw 'The output is already occupied; choose a new report filename.' }
foreach ($root in $inspectedRoots) {
    if ($destination.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or $destination.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Write the report outside the inspected game/library folder.'
    }
}
$reports = New-Object 'System.Collections.Generic.List[object]'
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($candidate in ($candidateFolders | Sort-Object)) {
    foreach ($prefix in @('', 'Content')) {
        $content = if ($prefix) { Join-Path $candidate $prefix } else { $candidate }
        if (-not [IO.Directory]::Exists($content) -or -not (Test-PlainPath $content)) { continue }
        foreach ($engine in @('Dungeons', 'Dun')) {
            $key = Join-Path $content $engine
            if ($seen.Contains($key)) { continue }
            $utocRelative = $engine + '\Content\Paks\global.utoc'
            $utoc = Join-Path $content $utocRelative
            if (-not [IO.File]::Exists($utoc)) { continue }
            $fingerprints = New-Object 'System.Collections.Generic.List[object]'
            foreach ($target in @('Win64', 'WinGDK')) {
                $binariesRelative = $engine + '\Binaries\' + $target
                $binaries = Join-Path $content $binariesRelative
                if (-not [IO.Directory]::Exists($binaries) -or -not (Test-PlainPath $binaries)) { continue }
                foreach ($shipping in (Get-ChildItem -LiteralPath $binaries -File -Filter ($engine + '*-Shipping.exe') | Sort-Object Name | Select-Object -First 4)) {
                    [void]$fingerprints.Add((Get-Fingerprint $shipping.FullName ($binariesRelative + '\' + $shipping.Name) -Version))
                }
            }
            $executableCount = $fingerprints.Count
            [void]$fingerprints.Add((Get-Fingerprint $utoc $utocRelative))
            [void]$seen.Add($key)
            $configLocation = Join-Path $content 'MicrosoftGame.config'
            $configRelative = 'MicrosoftGame.config'
            if (-not [IO.File]::Exists($configLocation) -and $prefix) {
                $configLocation = Join-Path $candidate 'MicrosoftGame.config'
                $configRelative = '..\MicrosoftGame.config'
            }
            $config = Get-ConfigSummary $configLocation
            $record = [ordered]@{
                CandidateIndex=$reports.Count + 1
                Status= $(if ($executableCount -gt 0) { 'LayoutCandidateOnly' } else { 'IncompleteLayoutCandidateOnly' })
                GameIdentityVerified=$false
                XboxRuntimeCompatibility='Unverified'
                InstallerCanInstallXbox=$false
                LayoutRelativeToSelectedFolder= $(if ($prefix) { $prefix } else { '.' })
                EngineDirectory=$engine
                MicrosoftConfigRelativePath= $(if ($null -ne $config) { $configRelative } else { $null })
                MicrosoftConfig=$config
                ShippingExecutableCount=$executableCount
                Files=@($fingerprints.ToArray())
            }
            if ($IncludePaths) { $record.ContentDirectory = $content }
            [void]$reports.Add($record)
        }
    }
}
$report = [ordered]@{
    Schema=1
    Purpose='Read-only Xbox/Game Pass compatibility preflight; not an installer'
    GeneratedUtc=[DateTime]::UtcNow.ToString('o')
    AbsoluteGamePathsIncluded=[bool]$IncludePaths
    CandidateCount=$reports.Count
    Candidates=@($reports.ToArray())
    Warnings=@($warnings.ToArray())
    WritablePermissionProbePerformed=$false
    GameFilesModified=$false
    ReportUploaded=$false
    Notes=@('Matching folder names or version strings do not prove runtime compatibility.', 'Dungeons and Dun with Win64/WinGDK shipping executables are candidate layouts; none is an approved Xbox profile.', 'No game content or character saves are included; only shipping-executable/global.utoc hashes and selected metadata are read.', 'Package and PE versions may differ from the version shown in the game menu.', 'Steam build validation remains unchanged. Xbox installation is not enabled.', 'Custom library folders require XboxLibraryRoots or GameDirectory; .GamingRoot is not parsed.')
}
$stream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
$writer = New-Object IO.StreamWriter($stream, (New-Object Text.UTF8Encoding($false)))
try { $writer.Write(($report | ConvertTo-Json -Depth 12)) } finally { $writer.Dispose() }
Write-Output $destination
