<#
.SYNOPSIS
    Smoke tests for the Kiro Autonomy installer.

.DESCRIPTION
    Runs the installer against an isolated temp settings.json, asserts the
    output matches expectations, and cleans up. No real Kiro install needed.

.NOTES
    Run: pwsh -File tests/Test-Script.ps1
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Write-Host is intentional for human-readable test output.')]
param()

$ErrorActionPreference = 'Stop'

# This script requires PowerShell 7+ (uses ConvertFrom-Json -AsHashtable)
if ($PSVersionTable.PSVersion.Major -lt 6) {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Write-Host 'Re-launching under pwsh (PowerShell 7)...' -ForegroundColor DarkGray
        & pwsh -NoProfile -File $PSCommandPath @PSBoundParameters
        exit $LASTEXITCODE
    }
    Write-Error 'PowerShell 7+ (pwsh) is required to run these tests.'
    exit 2
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repoRoot 'scripts/Enable-KiroFullAutonomy.ps1'
if (-not (Test-Path -LiteralPath $installer)) {
    Write-Error "Could not find installer at $installer"
    exit 2
}

$failures = @()
$total = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    $script:total++
    if ($Expected -is [Array] -and $Actual -is [Array]) {
        $eq = ($Expected.Count -eq $Actual.Count) -and -not (Compare-Object $Expected $Actual -SyncWindow 0)
    } else {
        $eq = $Expected -eq $Actual
    }
    if (-not $eq) {
        Write-Host "  [X] $Message" -ForegroundColor Red
        Write-Host "      expected: $($Expected | ConvertTo-Json -Compress)"
        Write-Host "      actual:   $($Actual   | ConvertTo-Json -Compress)"
        $script:failures += $Message
    } else {
        Write-Host "  [OK] $Message" -ForegroundColor Green
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:total++
    if ($Condition) {
        Write-Host "  [OK] $Message" -ForegroundColor Green
    } else {
        Write-Host "  [X] $Message" -ForegroundColor Red
        $script:failures += $Message
    }
}

function Read-SettingsFile {
    param([string]$Path)
    $text = Get-Content -Raw -LiteralPath $Path
    $text | ConvertFrom-Json -AsHashtable
}

# Setup workspace
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) "kiro-autonomy-test-$(Get-Random)"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$tmpSettings = Join-Path $workDir 'settings.json'

# Helper: invoke the installer cross-platform
function Invoke-Installer {
    param([string[]]$ExtraArgs)
    $argList = @('-NoProfile', '-File', $installer) + $ExtraArgs
    & pwsh @argList | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Installer exited with code $LASTEXITCODE. Args: $($ExtraArgs -join ' ')"
    }
}

try {
    # ---------------------------------------------------------------------
    Write-Host "`n== Test 1: maximum recipe on empty file ==" -ForegroundColor Cyan
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'maximum', '-Quiet')
    $s = Read-SettingsFile -Path $tmpSettings
    Assert-Equal 'Autopilot' $s['kiroAgent.agentAutonomy'] 'agentAutonomy = Autopilot'
    Assert-Equal @('*') $s['kiroAgent.trustedTools']    'trustedTools = ["*"]'
    Assert-Equal @('*') $s['kiroAgent.trustedCommands'] 'trustedCommands = ["*"]'
    Assert-Equal 'afterDelay' $s['files.autoSave'] 'files.autoSave default added'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 2: aggressive recipe overwrites maximum ==" -ForegroundColor Cyan
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'aggressive', '-Quiet')
    $s = Read-SettingsFile -Path $tmpSettings
    Assert-Equal 'Autopilot' $s['kiroAgent.agentAutonomy'] 'agentAutonomy stays Autopilot'
    Assert-Equal @('*') $s['kiroAgent.trustedTools'] 'trustedTools still ["*"]'
    Assert-True (-not ($s['kiroAgent.trustedCommands'] -contains '*')) 'aggressive does not contain "*"'
    Assert-True ($s['kiroAgent.trustedCommands'] -contains 'git status') 'aggressive contains "git status"'
    Assert-True ($s['kiroAgent.trustedCommands'].Count -gt 20) 'aggressive trustedCommands has many entries'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 3: conservative recipe ==" -ForegroundColor Cyan
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'conservative', '-Quiet')
    $s = Read-SettingsFile -Path $tmpSettings
    Assert-Equal 'Supervised' $s['kiroAgent.agentAutonomy'] 'agentAutonomy = Supervised'
    Assert-True ($s['kiroAgent.trustedTools'] -contains 'read_file') 'conservative trusts read_file'
    Assert-True (-not ($s['kiroAgent.trustedTools'] -contains '*')) 'conservative does not wildcard tools'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 4: existing settings preserved ==" -ForegroundColor Cyan
    @{
        'editor.fontSize' = 14
        'workbench.colorTheme' = 'Default Dark+'
    } | ConvertTo-Json | Set-Content -LiteralPath $tmpSettings
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'maximum', '-Quiet')
    $s = Read-SettingsFile -Path $tmpSettings
    Assert-Equal 14 $s['editor.fontSize'] 'editor.fontSize preserved'
    Assert-Equal 'Default Dark+' $s['workbench.colorTheme'] 'workbench.colorTheme preserved'
    Assert-Equal @('*') $s['kiroAgent.trustedCommands'] 'trustedCommands set'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 5: backup file created ==" -ForegroundColor Cyan
    $backups = Get-ChildItem -LiteralPath (Split-Path $tmpSettings -Parent) -Filter "$(Split-Path $tmpSettings -Leaf).bak.*"
    Assert-True ($backups.Count -ge 1) 'at least one backup file created'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 6: restore reverts to backup ==" -ForegroundColor Cyan
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Restore', '-Quiet')
    $s = Read-SettingsFile -Path $tmpSettings
    Assert-Equal 14 $s['editor.fontSize'] 'restore brings back editor.fontSize'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 7: reset removes all autonomy keys ==" -ForegroundColor Cyan
    @{
        'editor.fontSize' = 14
        'kiroAgent.agentAutonomy' = 'Autopilot'
        'kiroAgent.trustedTools' = @('*')
        'kiroAgent.trustedCommands' = @('*')
    } | ConvertTo-Json | Set-Content -LiteralPath $tmpSettings
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'reset', '-Quiet')
    $s = Read-SettingsFile -Path $tmpSettings
    Assert-Equal 14 $s['editor.fontSize'] 'editor.fontSize preserved on reset'
    Assert-True (-not $s.Contains('kiroAgent.agentAutonomy'))   'reset removes agentAutonomy'
    Assert-True (-not $s.Contains('kiroAgent.trustedTools'))    'reset removes trustedTools'
    Assert-True (-not $s.Contains('kiroAgent.trustedCommands')) 'reset removes trustedCommands'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 8: dry-run does not write ==" -ForegroundColor Cyan
    Set-Content -LiteralPath $tmpSettings -Value '{"a":1}'
    $beforeBytes = (Get-Item $tmpSettings).Length
    $beforeContent = Get-Content -Raw -LiteralPath $tmpSettings
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'maximum', '-DryRun', '-Quiet')
    $afterBytes = (Get-Item $tmpSettings).Length
    $afterContent = Get-Content -Raw -LiteralPath $tmpSettings
    Assert-Equal $beforeBytes $afterBytes 'dry-run preserves file size'
    Assert-Equal $beforeContent $afterContent 'dry-run preserves file content'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 9: JSONC input parses ==" -ForegroundColor Cyan
    $jsonc = "{`r`n    // a comment`r`n    `"editor.fontSize`": 14, // trailing comma below`r`n    `"workbench.colorTheme`": `"Dark+`",`r`n}"
    Set-Content -LiteralPath $tmpSettings -Value $jsonc -Encoding UTF8
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'maximum', '-Quiet')
    $s = Read-SettingsFile -Path $tmpSettings
    Assert-Equal 14 $s['editor.fontSize'] 'JSONC parsed: editor.fontSize'
    Assert-Equal 'Dark+' $s['workbench.colorTheme'] 'JSONC parsed: workbench.colorTheme'
    Assert-Equal @('*') $s['kiroAgent.trustedCommands'] 'JSONC parsed: trustedCommands set'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 10: idempotent (running twice yields same result) ==" -ForegroundColor Cyan
    Set-Content -LiteralPath $tmpSettings -Value '{}'
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'maximum', '-Quiet')
    $first = Get-Content -Raw -LiteralPath $tmpSettings
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'maximum', '-Quiet')
    $second = Get-Content -Raw -LiteralPath $tmpSettings
    Assert-Equal $first $second 'second run produces identical output'

    # ---------------------------------------------------------------------
    Write-Host "`n== Test 11: output is valid JSON ==" -ForegroundColor Cyan
    Invoke-Installer -ExtraArgs @('-SettingsPath', $tmpSettings, '-Recipe', 'aggressive', '-Quiet')
    $raw = Get-Content -Raw -LiteralPath $tmpSettings
    $parsed = $null
    try { $parsed = $raw | ConvertFrom-Json } catch { $parsed = $null }
    Assert-True ($null -ne $parsed) 'output parses as strict JSON (no JSONC needed)'

}
finally {
    Remove-Item -Recurse -Force -LiteralPath $workDir -ErrorAction SilentlyContinue
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host "All $total assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$($failures.Count) of $total assertions failed:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
