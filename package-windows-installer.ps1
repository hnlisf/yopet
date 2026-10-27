# Wrap a previously tested portable bundle; does not rebuild or install Yopet.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Bundle,
    [string]$IsccPath = ''
)
$ErrorActionPreference = 'Stop'
if (-not $IsccPath) {
    $IsccPath = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe'
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $IsccPath) { throw 'Inno Setup compiler not found; supply -IsccPath.' }
}
if (-not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) {
    throw 'Inno Setup compiler not found. Install Inno Setup 6 or supply -IsccPath. Nothing was installed.'
}
$bundlePath = (Resolve-Path -LiteralPath $Bundle).Path
$manifestPath = "$bundlePath.json"
if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Bundle manifest is required.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$hash = (Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash
if ($hash -ne $manifest.sha256) { throw 'Bundle SHA256 mismatch; refusing packaging.' }
if (-not $manifest.checksRun) { throw 'Use a bundle with checksRun=true.' }
$artifactDir = Join-Path $PSScriptRoot 'artifacts'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$stage = Join-Path $artifactDir "installer-stage-$stamp"
# Unique workspace staging directory; deliberately retained for inspection.
Expand-Archive -LiteralPath $bundlePath -DestinationPath $stage
$release = Join-Path $stage 'Release'
foreach ($required in @('yopet.exe', 'flutter_windows.dll', 'data\app.so', 'data\flutter_assets')) {
    if (-not (Test-Path -LiteralPath (Join-Path $release $required))) {
        throw "Incomplete input bundle: $required"
    }
}
$outputName = "yopet-windows-local-setup-$stamp"
& $IsccPath "/DSourceDir=$release" "/DOutputDir=$artifactDir" "/DOutputName=$outputName" (Join-Path $PSScriptRoot 'windows\installer\yopet.iss')
if ($LASTEXITCODE -ne 0) { throw "Installer compiler failed: $LASTEXITCODE" }
$installer = Join-Path $artifactDir "$outputName.exe"
if (-not (Test-Path -LiteralPath $installer)) { throw 'Installer output missing.' }
[ordered]@{
    installer = Split-Path -Leaf $installer
    sha256 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
    sourceBundle = Split-Path -Leaf $bundlePath
    sourceSha256 = $hash
    builtAt = (Get-Date).ToString('o')
    signed = $false
    purpose = 'Local testing only; localhost Docker backend required'
} | ConvertTo-Json | Set-Content -LiteralPath "$installer.json" -Encoding utf8
Write-Host "Installer: $installer"
Write-Host 'Unsigned local test installer. No installation or publication performed.'
