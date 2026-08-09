# yopet run-dev.ps1
# Wrapper that reads ../supabase-local/docker/.env and starts flutter run
# with correct SUPABASE_URL / SUPABASE_ANON_KEY dart-defines.
#
# Usage:
#   .\run-dev.ps1                  # default: Windows desktop, URL from .env
#   .\run-dev.ps1 -Platform android  # Android emulator: host translated to 10.0.2.2
#   .\run-dev.ps1 -Url http://example:54321  # override URL (debug)
#
# Prerequisites:
#   - Flutter SDK installed and on PATH (`flutter --version` works)
#   - Supabase stack running (see ../supabase-local/docker/README and
#     docs/setup/local-supabase.md)

[CmdletBinding()]
param(
    [ValidateSet('windows', 'android')]
    [string]$Platform = 'windows',

    [string]$Url = ''
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 1. Resolve the .env path (relative to this script's location)
# ---------------------------------------------------------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envPath = Join-Path $scriptDir '..\supabase-local\docker\.env'

if (-not (Test-Path $envPath)) {
    Write-Error "Cannot find Supabase .env at: $envPath`nRun F1 first (see docs/setup/local-supabase.md). Aborting."
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Parse .env (simple key=value parser, supports # comments and quoted vals)
# ---------------------------------------------------------------------------
function Read-EnvValue {
    param([string]$Path, [string]$Key)
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^(?!\s*#)(?!\s*$)') {
            $kv = $line -split '=', 2
            if ($kv.Count -eq 2 -and $kv[0].Trim() -eq $Key) {
                return $kv[1].Trim().Trim('"').Trim("'")
            }
        }
    }
}

$envSupabaseUrl = Read-EnvValue -Path $envPath -Key 'SUPABASE_PUBLIC_URL'
$envKongPort     = Read-EnvValue -Path $envPath -Key 'KONG_HTTP_PORT'
$envAnonKey      = Read-EnvValue -Path $envPath -Key 'ANON_KEY'

# ---------------------------------------------------------------------------
# 3. Resolve URL: -Url override > SUPABASE_PUBLIC_URL > localhost:54321
# ---------------------------------------------------------------------------
if ($Url -ne '') {
    $supabaseUrl = $Url
} elseif ($envSupabaseUrl) {
    $supabaseUrl = $envSupabaseUrl
} else {
    $port = if ($envKongPort) { $envKongPort } else { '54321' }
    $supabaseUrl = "http://localhost:${port}"
}

if (-not $envAnonKey) {
    Write-Error "ANON_KEY not found in $envPath.`nF1 stack must be up and `.env` must contain a valid ANON_KEY. Aborting."
    exit 1
}

# ---------------------------------------------------------------------------
# 4. Translate URL host for Android emulator
# ---------------------------------------------------------------------------
if ($Platform -eq 'android') {
    # Android emulator routes 10.0.2.2 -> host machine's localhost
    $parsed = [System.UriBuilder]::new($supabaseUrl)
    if ($parsed.Host -eq 'localhost' -or $parsed.Host -eq '127.0.0.1') {
        $parsed.Host = '10.0.2.2'
    }
    $supabaseUrl = $parsed.Uri.ToString()
}

# ---------------------------------------------------------------------------
# 5. Map Platform to flutter run -d target
# ---------------------------------------------------------------------------
$flutterTarget = switch ($Platform) {
    'windows' { 'windows' }
    'android' { 'android' }
}

# ---------------------------------------------------------------------------
# 6. Run flutter
# ---------------------------------------------------------------------------
Write-Host "yopet dev launcher" -ForegroundColor Cyan
Write-Host "  Platform: $Platform  (flutter -d $flutterTarget)"
Write-Host "  URL:      $supabaseUrl"
Write-Host "  AnonKey:  $($envAnonKey.Substring(0, [Math]::Min(20, $envAnonKey.Length)))..."
Write-Host ""

flutter run -d $flutterTarget `
    --dart-define=SUPABASE_URL="$supabaseUrl" `
    --dart-define=SUPABASE_ANON_KEY="$envAnonKey"