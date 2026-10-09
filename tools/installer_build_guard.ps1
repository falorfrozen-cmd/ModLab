$ErrorActionPreference = 'Stop'

function Assert-ModLabCompiler {
    param([string]$Path, [string]$Publisher)
    $compilerPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
        throw ('Compiler is missing: ' + $compilerPath)
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $compilerPath
    $publisherPattern = '(?:^|,\s*)O=' + [regex]::Escape($Publisher) + '(?:,|$)'
    if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
        $signature.SignerCertificate.Subject -notmatch $publisherPattern) {
        throw ('Compiler signature is not valid for ' + $Publisher + ': ' + $compilerPath)
    }
    return [pscustomobject]@{
        Path = $compilerPath
        SHA256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
        Publisher = $signature.SignerCertificate.Subject
        CertificateThumbprint = $signature.SignerCertificate.Thumbprint
        SignatureStatus = $signature.Status.ToString()
    }
}

function Assert-ModLabBuildOutput {
    param([string]$Directory, [string]$Version)
    $setupPath = Join-Path $Directory ('ModLab-Setup-' + $Version + '.exe')
    $recordPath = Join-Path $Directory ('standard-installer-build-' + $Version + '.json')
    if ((Test-Path -LiteralPath $setupPath) -or (Test-Path -LiteralPath $recordPath)) {
        throw ('Release output already exists. Preserve its scan identity; select a new version or an isolated OutputDirectory: ' + $setupPath)
    }
}
