<#
.SYNOPSIS
    Replaces the rahul6396346 placeholder across the repo with your actual GitHub
    username/org. Run once before pushing to GitHub.

.PARAMETER Owner
    Your GitHub username or organization name.

.EXAMPLE
    pwsh -File scripts/set-repo-owner.ps1 -Owner my-username
#>

[CmdletBinding(SupportsShouldProcess)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Write-Host is intentional for human-readable script output.')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,38}$')]
    [string]$Owner
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

$targetExts = @('*.md', '*.ps1', '*.sh', '*.bat', '*.yml', '*.yaml', '*.json', '*.jsonc')
$count = 0

Get-ChildItem -Path $repoRoot -Recurse -File -Include $targetExts |
    Where-Object { $_.FullName -notmatch '\\(node_modules|\.git)\\' } |
    ForEach-Object {
        $content = Get-Content -Raw -LiteralPath $_.FullName
        if ($content -match 'rahul6396346') {
            $new = $content -replace 'rahul6396346', $Owner
            if ($PSCmdlet.ShouldProcess($_.FullName, "Replace rahul6396346 -> $Owner")) {
                Set-Content -LiteralPath $_.FullName -Value $new -NoNewline -Encoding UTF8
                Write-Host ('  ' + $_.FullName.Substring($repoRoot.Path.Length + 1)) -ForegroundColor DarkGreen
                $script:count++
            }
        }
    }

Write-Host ''
Write-Host "Replaced rahul6396346 -> $Owner in $count file(s)." -ForegroundColor Green
