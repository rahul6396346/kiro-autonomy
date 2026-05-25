<#
.SYNOPSIS
    One-liner remote installer for Kiro Autonomy on Windows.

.DESCRIPTION
    Use:
      iwr -useb https://raw.githubusercontent.com/rahul6396346/kiro-autonomy/main/scripts/install.ps1 | iex

    Or with environment variables (set before piping):
      $env:KIRO_AUTONOMY_RECIPE = 'aggressive'
      iwr -useb https://raw.githubusercontent.com/rahul6396346/kiro-autonomy/main/scripts/install.ps1 | iex

    Available env vars:
      KIRO_AUTONOMY_RECIPE         maximum | aggressive | conservative | reset
      KIRO_AUTONOMY_RESTORE        any non-empty value triggers -Restore
      KIRO_AUTONOMY_DRYRUN         any non-empty value triggers -DryRun
      KIRO_AUTONOMY_REPO_RAW       override raw repo URL
      KIRO_AUTONOMY_SETTINGS_PATH  override settings.json path
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Write-Host is intentional for human-readable installer output to console.')]
param()

$ErrorActionPreference = 'Stop'

$repoRaw   = if ($env:KIRO_AUTONOMY_REPO_RAW) { $env:KIRO_AUTONOMY_REPO_RAW } else { 'https://raw.githubusercontent.com/rahul6396346/kiro-autonomy/main' }
$scriptUrl = "$repoRaw/scripts/Enable-KiroFullAutonomy.ps1"

Write-Host '=== Kiro Autonomy installer ===' -ForegroundColor Cyan
Write-Host "Fetching: $scriptUrl"             -ForegroundColor DarkGray

# Use a .ps1 file (not .tmp) so PowerShell can execute it
$tmpDir  = [System.IO.Path]::GetTempPath()
$tmpFile = Join-Path $tmpDir ("kiro-autonomy-{0}.ps1" -f ([Guid]::NewGuid().ToString('N')))

try {
    Invoke-WebRequest -UseBasicParsing -Uri $scriptUrl -OutFile $tmpFile

    $params = @{}
    if ($env:KIRO_AUTONOMY_RECIPE)        { $params.Recipe       = $env:KIRO_AUTONOMY_RECIPE }
    if ($env:KIRO_AUTONOMY_RESTORE)       { $params.Restore      = $true }
    if ($env:KIRO_AUTONOMY_DRYRUN)        { $params.DryRun       = $true }
    if ($env:KIRO_AUTONOMY_SETTINGS_PATH) { $params.SettingsPath = $env:KIRO_AUTONOMY_SETTINGS_PATH }

    & $tmpFile @params
}
finally {
    if (Test-Path -LiteralPath $tmpFile) {
        Remove-Item -LiteralPath $tmpFile -ErrorAction SilentlyContinue
    }
}
