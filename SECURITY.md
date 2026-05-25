# Security Policy

## Reporting a vulnerability

If you find a security issue with the installer or anything else in this repo, please **do not open a public issue**.

Instead:
1. Open a [GitHub Security Advisory](https://github.com/rahul6396346/kiro-autonomy/security/advisories/new) (preferred), **or**
2. Email the maintainers (address in the repo's `MAINTAINERS.md` if present)

Please include:
- A description of the issue
- Steps to reproduce
- Affected versions
- Any suggested mitigations

We aim to acknowledge reports within 72 hours.

## Scope

This repo is documentation + small shell/PowerShell scripts. The main security surface is:

- The installer scripts modifying `settings.json`
- Remote one-liner installers (`install.ps1`, `install.sh`) that fetch and execute code

If you find a way for these to misbehave, leak data, or alter unintended files, that's in scope.

## Out of scope

- Bugs in Kiro itself — please report those to the Kiro team
- General complaints about the philosophy of `trustedCommands: ["*"]` — see [docs/SECURITY.md](docs/SECURITY.md) for the considered tradeoffs

## See also

- [docs/SECURITY.md](docs/SECURITY.md) — risk discussion and mitigations for full-trust mode
