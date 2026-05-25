# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-05-25

### Added
- Cross-platform PowerShell installer (`Enable-KiroFullAutonomy.ps1`) supporting Windows, macOS, Linux
- Bash installer (`enable-kiro-autonomy.sh`) for users without PowerShell
- Windows double-click launcher (`enable-kiro-autonomy.bat`)
- One-liner remote installers (`install.ps1`, `install.sh`) for direct curl/iwr piping
- Comprehensive 14-section guide (`docs/GUIDE.md`) verified against `kiro.kiro-agent` v0.3.433
- Recipe library (`docs/RECIPES.md`) covering Maximum, Aggressive, Conservative, and Per-workspace configs
- Security and risk documentation (`docs/SECURITY.md`)
- Verification guide (`docs/VERIFICATION.md`) with reproducible PowerShell commands
- Troubleshooting guide (`docs/TROUBLESHOOTING.md`)
- FAQ (`docs/FAQ.md`)
- Four ready-to-paste example settings files
- GitHub issue templates and CI workflow
- Smoke tests (`tests/Test-Script.ps1`) — 28 PowerShell assertions across 11 scenarios

### Tested
- PowerShell installer: 28/28 assertions pass
- Bash installer: 18/18 assertions pass (jq backend) plus python3 fallback
- PSScriptAnalyzer: clean (zero errors, zero warnings)
- markdownlint: clean
- All example JSON files validate
- Idempotent: running twice produces identical output
- Cross-platform path detection verified for Windows/macOS/Linux
- Restore round-trips correctly
- JSONC input (with comments and trailing commas) parses cleanly

### Verified Internals
- `trustedCommands` matcher confirmed to honor `"*"` wildcard
- Prefix matching with `"<word> *"` syntax confirmed working
- Whitespace normalization via trim + collapse confirmed
- Default denylist confirmed empty in v0.3.433

[Unreleased]: https://github.com/rahul6396346/kiro-autonomy/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/rahul6396346/kiro-autonomy/releases/tag/v1.0.0
