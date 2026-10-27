# Build and package a local Windows test bundle; never deploys or stops apps.
[CmdletBinding()]
param(
    [string]$FlutterPath = 'flutter',
    [string]$Url = '',
    [switch]$SkipChecks
)

$ErrorActionPreference = 'Stop'
$releaseDir = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'
$artifactDir = Join-Path $PSScriptRoot 'artifacts'
if (Get-Process -Name yopet -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and (Split-Path -Parent $_.Path) -eq $releaseDir
}) {
    throw 'Close the Release Yopet window before packaging. No process was stopped.'
}
if (-not $SkipChecks) {
    & (Join-Path $PSScriptRoot 'verify-local.ps1') -FlutterPath $FlutterPath -SkipWebBuild
}
$buildArgs = @{ Platform = 'windows'; BuildOnly = $true;
    FlutterPath = $FlutterPath; NoPub = $true }
if ($Url) { $buildArgs.Url = $Url }
& (Join-Path $PSScriptRoot 'run-dev.ps1') @buildArgs
foreach ($required in @('yopet.exe', 'flutter_windows.dll', 'data\flutter_assets', 'data\app.so')) {
    if (-not (Test-Path -LiteralPath (Join-Path $releaseDir $required))) {
        throw "Incomplete Windows build: missing $required. No bundle created."
    }
}
$null = New-Item -ItemType Directory -Path $artifactDir -Force
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$bundle = Join-Path $artifactDir "yopet-windows-local-$stamp.zip"
# Archive the complete Release directory, not just the executable.
Compress-Archive -LiteralPath $releaseDir -DestinationPath $bundle
$hash = (Get-FileHash -LiteralPath $bundle -Algorithm SHA256).Hash
$revision = & git -C $PSScriptRoot rev-parse --short HEAD
$dirty = @(& git -C $PSScriptRoot status --porcelain --untracked-files=no).Count -gt 0
$manifest = [ordered]@{
    bundle = Split-Path -Leaf $bundle
    bytes = (Get-Item -LiteralPath $bundle).Length
    sha256 = $hash
    builtAt = (Get-Date).ToString('o')
    revision = "$revision"
    trackedChanges = $dirty
    checksRun = -not [bool]$SkipChecks
    purpose = 'Local Windows testing; not a signed production release'
    runtime = 'Extract the entire Release folder. Supabase must be reachable. No credentials included in this manifest.'
}
# Generated build metadata, not application configuration or a secret dump.
$manifest | ConvertTo-Json | Set-Content -LiteralPath "$bundle.json" -Encoding utf8
Write-Host "Bundle: $bundle" -ForegroundColor Green
Write-Host "SHA256: $hash"
Write-Host 'Extract the complete Release folder. Do not copy only yopet.exe.'
