# Local compile/test gate only. Does not deploy, read secrets or reset databases.
[CmdletBinding()]
param(
    [string]$FlutterPath = 'flutter',
    [switch]$SkipWebBuild
)

$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $checks = @(
        @{ Name = 'Static analysis'; Arguments = @('analyze', '--no-pub') },
        @{ Name = 'Flutter tests'; Arguments = @('test', '--no-pub') }
    )
    if (-not $SkipWebBuild) {
        $checks += @{ Name = 'Release Web compile (not deployment)';
            Arguments = @('build', 'web', '--release', '--no-pub') }
    }
    foreach ($check in $checks) {
        Write-Host $check.Name -ForegroundColor Cyan
        $checkArguments = $check.Arguments
        & $FlutterPath @checkArguments
        if ($LASTEXITCODE -ne 0) {
            throw "$($check.Name) failed with exit code $LASTEXITCODE."
        }
    }
    Write-Host 'Local checks passed. Production auth, device QA and deployment remain separate.' -ForegroundColor Green
} finally {
    Pop-Location
}
