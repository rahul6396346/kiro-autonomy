<#
.SYNOPSIS
    Enable full autonomous mode for Kiro IDE in one click.

.DESCRIPTION
    Configures Kiro user-level settings.json with the three keys required
    for end-to-end autonomous agent execution:

      kiroAgent.agentAutonomy   = "Autopilot"
      kiroAgent.trustedTools    = ["*"]
      kiroAgent.trustedCommands = ["*"]

    The script is non-destructive: it merges into your existing settings,
    creates a timestamped backup before writing, preserves all unrelated
    keys, and is safe to run multiple times.

    Cross-platform: works on Windows (Windows PowerShell 5.1+ or pwsh 7+),
    macOS, and Linux (pwsh 7+).

.PARAMETER Restore
    Restore settings.json from the most recent .bak file in the same dir.

.PARAMETER DryRun
    Print what the new settings.json would contain without writing it.

.PARAMETER Recipe
    Apply a named recipe instead of the default ("maximum"). Options:
      maximum       - trust everything (default)
      aggressive    - trust common dev commands, leave the rest gated
      conservative  - read-only trust, supervised file edits
      reset         - clear all autonomy keys (back to Kiro defaults)

.PARAMETER SettingsPath
    Override the auto-detected settings.json path. Useful for testing.

.PARAMETER Quiet
    Suppress non-essential output.

.EXAMPLE
    pwsh -File Enable-KiroFullAutonomy.ps1
    Apply maximum-autonomy preset to the user-level settings.json.

.EXAMPLE
    pwsh -File Enable-KiroFullAutonomy.ps1 -Recipe aggressive
    Apply the bounded-trust preset.

.EXAMPLE
    pwsh -File Enable-KiroFullAutonomy.ps1 -Restore
    Roll back to the most recent backup.

.EXAMPLE
    pwsh -File Enable-KiroFullAutonomy.ps1 -DryRun
    Preview the result without writing.

.NOTES
    Verified against kiro.kiro-agent v0.3.433.
    Project: https://github.com/rahul6396346/kiro-autonomy
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Write-Host is intentional for human-readable installer output to console.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
    Justification = 'Parameters are used in script-level scope which PSSA does not always trace.')]
param(
    [switch]$Restore,
    [switch]$DryRun,
    [ValidateSet('maximum', 'aggressive', 'conservative', 'reset')]
    [string]$Recipe = 'maximum',
    [string]$SettingsPath,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------

function Write-Info {
    param([string]$Message, [string]$Color = 'Cyan')
    if (-not $Quiet) { Write-Host $Message -ForegroundColor $Color }
}

function Write-Success {
    param([string]$Message)
    if (-not $Quiet) { Write-Host $Message -ForegroundColor Green }
}

function Resolve-SettingsPath {
    if ($SettingsPath) { return $SettingsPath }

    # Detect OS without depending on PS7 automatic vars (works in WinPS too)
    $platform = if ($PSVersionTable.PSVersion.Major -ge 6) {
        if ($IsMacOS)   { 'macOS' }
        elseif ($IsLinux) { 'Linux' }
        else { 'Windows' }
    } else {
        'Windows'
    }

    switch ($platform) {
        'macOS'   { return Join-Path $HOME 'Library/Application Support/Kiro/User/settings.json' }
        'Linux'   { return Join-Path $HOME '.config/Kiro/User/settings.json' }
        'Windows' { return Join-Path $env:APPDATA 'Kiro\User\settings.json' }
    }
}

function Read-JsonWithComment {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return [ordered]@{} }
    $raw = Get-Content -Raw -LiteralPath $Path
    if ([string]::IsNullOrWhiteSpace($raw)) { return [ordered]@{} }

    # Strip JSONC: block comments, line comments, trailing commas
    $stripped = [regex]::Replace($raw, '/\*[\s\S]*?\*/', '')
    $stripped = [regex]::Replace($stripped, '(?m)^\s*//.*$', '')
    $stripped = [regex]::Replace($stripped, ',(\s*[}\]])', '$1')

    if ([string]::IsNullOrWhiteSpace($stripped)) { return [ordered]@{} }

    try {
        # PS 7+ supports -AsHashtable which preserves ordering and gives us mutable maps
        $obj = $stripped | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($obj -isnot [System.Collections.IDictionary]) {
            $h = [ordered]@{}
            foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
            return $h
        }
        # Convert hashtable to ordered to preserve insertion order
        $ordered = [ordered]@{}
        foreach ($key in $obj.Keys) { $ordered[$key] = $obj[$key] }
        return $ordered
    }
    catch [System.Management.Automation.ParameterBindingException] {
        # WinPS 5.1 has no -AsHashtable
        $obj = $stripped | ConvertFrom-Json -ErrorAction Stop
        $h = [ordered]@{}
        if ($null -ne $obj) {
            foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
        }
        return $h
    }
    catch {
        throw "Could not parse settings.json. Fix or delete the file and try again. Error: $_"
    }
}

function Backup-File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = "$Path.bak.$stamp"
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    return $bak
}

function Get-LatestBackup {
    param([string]$Path)
    $dir = Split-Path -Parent $Path
    $name = Split-Path -Leaf $Path
    Get-ChildItem -LiteralPath $dir -Filter "$name.bak.*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Convert-ToOrderedHashtable {
    param($Object)
    if ($null -eq $Object) { return [ordered]@{} }
    if ($Object -is [System.Collections.IDictionary]) {
        $o = [ordered]@{}
        foreach ($k in $Object.Keys) { $o[$k] = $Object[$k] }
        return $o
    }
    $o = [ordered]@{}
    foreach ($p in $Object.PSObject.Properties) { $o[$p.Name] = $p.Value }
    return $o
}

function Write-JsonFile {
    param(
        [string]$Path,
        [System.Collections.IDictionary]$Data
    )
    $json = $Data | ConvertTo-Json -Depth 50

    # PowerShell ConvertTo-Json sometimes renders single-element arrays as
    # scalars. Force the trust arrays back to arrays for strict JSON validity.
    $json = [regex]::Replace($json, '"kiroAgent\.trustedTools":\s*"([^"]+)"',  '"kiroAgent.trustedTools": ["$1"]')
    $json = [regex]::Replace($json, '"kiroAgent\.trustedCommands":\s*"([^"]+)"','"kiroAgent.trustedCommands": ["$1"]')

    # UTF-8 without BOM (VS Code / Kiro requirement)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $enc)
}

# ----------------------------------------------------------------------
# Recipes
# ----------------------------------------------------------------------

function Get-RecipeKey {
    param([string]$Name)

    switch ($Name) {
        'maximum' {
            return @{
                'kiroAgent.agentAutonomy'   = 'Autopilot'
                'kiroAgent.trustedTools'    = @('*')
                'kiroAgent.trustedCommands' = @('*')
            }
        }
        'aggressive' {
            return @{
                'kiroAgent.agentAutonomy' = 'Autopilot'
                'kiroAgent.trustedTools'  = @('*')
                'kiroAgent.trustedCommands' = @(
                    'node *', 'npm *', 'npx *', 'pnpm *', 'yarn *', 'bun *',
                    'python *', 'py *', 'pip *', 'uv *', 'uvx *', 'poetry *',
                    'go *', 'cargo *', 'rustc *',
                    'java *', 'javac *', 'mvn *', 'gradle *',
                    'dotnet *', 'make *', 'cmake *',
                    'git status', 'git status -s', 'git diff', 'git diff --cached',
                    'git log', 'git log --oneline -20', 'git show', 'git branch',
                    'git add *', 'git commit *', 'git pull', 'git fetch',
                    'git checkout *', 'git switch *', 'git stash', 'git stash *',
                    'dir', 'dir *', 'type *', 'where *', 'echo *', 'cls',
                    'Get-ChildItem *', 'Get-Content *', 'Select-String *',
                    'ls *', 'cat *', 'grep *', 'find *', 'head *', 'tail *',
                    'docker *', 'kubectl *', 'terraform *',
                    'curl *', 'wget *', 'ping *', 'nslookup *',
                    'tsc *', 'eslint *', 'prettier *', 'vitest *', 'jest *', 'pytest *'
                )
            }
        }
        'conservative' {
            return @{
                'kiroAgent.agentAutonomy' = 'Supervised'
                'kiroAgent.trustedTools'  = @(
                    'read_file', 'read_files', 'list_directory',
                    'grep_search', 'file_search',
                    'remote_web_search', 'web_fetch'
                )
                'kiroAgent.trustedCommands' = @(
                    'node --version', 'npm --version', 'python --version',
                    'git status', 'git diff',
                    'dir', 'type *', 'Get-ChildItem'
                )
            }
        }
        'reset' {
            return @{
                'kiroAgent.agentAutonomy'   = $null
                'kiroAgent.trustedTools'    = $null
                'kiroAgent.trustedCommands' = $null
            }
        }
    }
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

$resolvedPath = Resolve-SettingsPath
Write-Info "Kiro user settings: $resolvedPath" 'Cyan'

# --- Restore ---
if ($Restore) {
    $bak = Get-LatestBackup -Path $resolvedPath
    if (-not $bak) {
        Write-Host 'No backup file found to restore.' -ForegroundColor Yellow
        exit 1
    }
    if ($DryRun) {
        Write-Info "Would restore from: $($bak.FullName)" 'Yellow'
        exit 0
    }
    Copy-Item -LiteralPath $bak.FullName -Destination $resolvedPath -Force
    Write-Success "Restored from $($bak.Name)"
    Write-Info 'Reload Kiro to apply: Ctrl+Shift+P -> Developer: Reload Window' 'Yellow'
    exit 0
}

# Ensure the directory exists
$settingsDir = Split-Path -Parent $resolvedPath
if (-not (Test-Path -LiteralPath $settingsDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }
    Write-Info "Created settings directory: $settingsDir" 'DarkGray'
}

# Load existing settings
$current = Read-JsonWithComment -Path $resolvedPath
$current = Convert-ToOrderedHashtable -Object $current

# Apply recipe
$keys = Get-RecipeKey -Name $Recipe
Write-Info "Applying recipe: $Recipe" 'Cyan'

foreach ($k in @($keys.Keys)) {
    $v = $keys[$k]
    if ($null -eq $v) {
        if ($current.Contains($k)) {
            $current.Remove($k)
            Write-Info "  removed: $k" 'DarkGray'
        }
    } else {
        $current[$k] = $v
        Write-Info "  set:     $k" 'DarkGray'
    }
}

# Quality-of-life defaults - only added if missing
if ($Recipe -ne 'reset') {
    if (-not $current.Contains('files.autoSave'))                  { $current['files.autoSave'] = 'afterDelay' }
    if (-not $current.Contains('kiroAgent.enableTabAutocomplete')) { $current['kiroAgent.enableTabAutocomplete'] = $true }
    if (-not $current.Contains('kiroAgent.enableCodebaseIndexing')){ $current['kiroAgent.enableCodebaseIndexing'] = $true }
}

# Dry run output
if ($DryRun) {
    Write-Info '--- DRY RUN: would write the following ---' 'Yellow'
    $preview = $current | ConvertTo-Json -Depth 50
    $preview = [regex]::Replace($preview, '"kiroAgent\.trustedTools":\s*"([^"]+)"',  '"kiroAgent.trustedTools": ["$1"]')
    $preview = [regex]::Replace($preview, '"kiroAgent\.trustedCommands":\s*"([^"]+)"','"kiroAgent.trustedCommands": ["$1"]')
    Write-Output $preview
    exit 0
}

# Backup + write
$backupPath = Backup-File -Path $resolvedPath
if ($backupPath) {
    Write-Info "Backed up: $backupPath" 'DarkGray'
}

Write-JsonFile -Path $resolvedPath -Data $current

Write-Output ''
Write-Success "Kiro autonomy: $Recipe applied."
Write-Output ''
Write-Info 'Final step: reload Kiro to apply.' 'Yellow'
Write-Info '  Ctrl+Shift+P  ->  Developer: Reload Window' 'Yellow'
Write-Output ''

if ($backupPath) {
    Write-Info 'To roll back to your previous settings:' 'DarkGray'
    Write-Info "  pwsh -File `"$PSCommandPath`" -Restore" 'DarkGray'
}
