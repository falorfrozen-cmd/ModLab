param([string]$InnoCompiler)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\installer_build_guard.ps1')
$guardFixture = Join-Path ([IO.Path]::GetTempPath()) ('ModLab-build-guard-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $guardFixture | Out-Null

# This file must be rejected as a compiler, never invoked by the build.
$fakeCompiler = Join-Path $guardFixture 'untrusted-compiler.exe'
[IO.File]::WriteAllText($fakeCompiler, 'This is not a signed compiler.')
try { Assert-ModLabCompiler $fakeCompiler 'Pyrsys B.V.' | Out-Null; throw 'Unsigned compiler accepted.' }
catch { if ($_.Exception.Message -notlike 'Compiler signature is not valid*') { throw } }

$trustedCompiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$trustedRecord = Assert-ModLabCompiler $trustedCompiler 'Microsoft Corporation'
if ($trustedRecord.SignatureStatus -ne 'Valid' -or $trustedRecord.SHA256 -notmatch '^[A-F0-9]{64}$') { throw 'Missing trusted compiler audit.' }
try { Assert-ModLabCompiler $trustedCompiler 'Pyrsys B.V.' | Out-Null; throw 'Wrong publisher accepted.' }
catch { if ($_.Exception.Message -notlike 'Compiler signature is not valid*') { throw } }
if ($InnoCompiler) { Assert-ModLabCompiler $InnoCompiler 'Pyrsys B.V.' | Out-Null }

$existingSetup = Join-Path $guardFixture 'ModLab-Setup-0.1.0-test.exe'
[IO.File]::WriteAllText($existingSetup, 'preserved published file sentinel')
$preservedHash = (Get-FileHash -LiteralPath $existingSetup).Hash
try { Assert-ModLabBuildOutput $guardFixture '0.1.0-test'; throw 'Existing release accepted.' }
catch { if ($_.Exception.Message -notlike 'Release output already exists*') { throw } }
if ((Get-FileHash -LiteralPath $existingSetup).Hash -ne $preservedHash) { throw 'Existing release changed.' }
Assert-ModLabBuildOutput $guardFixture '0.1.0-other'
Write-Output ('PASS build guard: unsigned and wrong-publisher compiler rejection, trusted compiler audit, existing release preservation. Evidence: ' + $guardFixture)
