<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# 🚀 Kiro Autonomy

### Make [Kiro IDE](https://kiro.dev) stop asking. Run the agent end-to-end with one click.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
![Windows](https://img.shields.io/badge/Windows-supported-0078D6?logo=windows&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-supported-000?logo=apple&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-supported-FCC624?logo=linux&logoColor=black)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![CI](https://img.shields.io/github/actions/workflow/status/rahul6396346/kiro-autonomy/ci.yml?branch=main&logo=github)](../../actions/workflows/ci.yml)

**One script. One reload. Zero approval prompts.**

[Quick Start](#-quick-start) · [Why This Exists](#-why-this-exists) · [How It Works](#-how-it-works) · [Recipes](docs/RECIPES.md) · [Safety](docs/SECURITY.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)

</div>

---

## 🎯 The Problem

You set Kiro to **Autopilot** mode expecting it to run autonomously, but every shell command and tool call still pops a `Trust / Run / Reject` dialog that yanks you out of flow:

```
┌──────────────────────────────────────────────────────┐
│  Waiting on your input.        [Reject] [Trust] [Run]│
└──────────────────────────────────────────────────────┘
```

Clicking **Trust** only whitelists that one exact command string. Run a slightly different command? New popup. The Settings UI doesn't expose any "trust everything" option, and the docs don't mention one exists.

## 💡 The Fix

Kiro's `trustedCommands` matcher **does** support a `"*"` wildcard — it's just not surfaced anywhere. This repo gives you:

- A **one-click installer** that configures it correctly without breaking your existing settings
- A **comprehensive guide** with verified internals
- **Recipe configs** from cautious to maximum autonomy
- **Reversible** — every run creates a timestamped backup

## ⚡ Quick Start

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/rahul6396346/kiro-autonomy/main/scripts/install.ps1 | iex
```

Or download and double-click [`enable-kiro-autonomy.bat`](scripts/enable-kiro-autonomy.bat).

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/rahul6396346/kiro-autonomy/main/scripts/install.sh | bash
```

### Manual (any OS)

Add this to your Kiro user `settings.json`:

```jsonc
{
  "kiroAgent.agentAutonomy": "Autopilot",
  "kiroAgent.trustedTools": ["*"],
  "kiroAgent.trustedCommands": ["*"]
}
```

Settings location:
- **Windows:** `%APPDATA%\Kiro\User\settings.json`
- **macOS:** `~/Library/Application Support/Kiro/User/settings.json`
- **Linux:** `~/.config/Kiro/User/settings.json`

Then reload: `Ctrl+Shift+P` → `Developer: Reload Window`.

That's it. No more popups.

## 🔬 Why This Exists

We dug into Kiro's compiled extension (`kiro.kiro-agent` v0.3.433) to find the actual decision logic. The matcher is six lines of JavaScript and explicitly accepts a wildcard:

```js
function matches(cmd, trusted, denied) {
  if (denied.some(d => cmd.includes(d))) return false;
  if (trusted.includes("*")) return true;          // ← the wildcard
  return trusted.some(t => /* exact / prefix match */);
}
```

But this isn't documented, and the Settings UI never exposes it. Most users hit `Trust` 30 times a session and never realize there's a better way. **This repo fixes that.**

Full reverse-engineering writeup: [docs/VERIFICATION.md](docs/VERIFICATION.md).

## 🧠 How It Works

Kiro has three independent approval gates. To go fully autonomous you need all three:

| Gate | Setting | Wildcard | Effect |
|---|---|---|---|
| **Autonomy mode** | `kiroAgent.agentAutonomy` | `"Autopilot"` | No per-edit approvals |
| **Tool trust** | `kiroAgent.trustedTools` | `["*"]` | No tool approval prompts |
| **Command trust** | `kiroAgent.trustedCommands` | `["*"]` | No shell command popups |

The installer sets all three correctly, preserves your other settings, and creates a backup.

Detailed walkthrough: [docs/GUIDE.md](docs/GUIDE.md).

## 📦 What's In This Repo

```
kiro-autonomy/
├── scripts/
│   ├── Enable-KiroFullAutonomy.ps1   ← cross-platform PowerShell installer
│   ├── enable-kiro-autonomy.sh       ← bash installer (macOS / Linux)
│   ├── enable-kiro-autonomy.bat      ← double-click launcher (Windows)
│   ├── install.ps1                   ← one-liner remote installer (Windows)
│   ├── install.sh                    ← one-liner remote installer (Unix)
│   └── set-repo-owner.ps1            ← replaces rahul6396346 placeholder before pushing
├── examples/
│   ├── settings.maximum.json         ← trust everything (this repo's default)
│   ├── settings.aggressive.json      ← trust common dev commands only
│   ├── settings.conservative.json    ← read-only trust, supervised edits
│   └── settings.workspace-override.json  ← restrict trust per-workspace
├── docs/
│   ├── GUIDE.md                      ← complete 14-section reference
│   ├── RECIPES.md                    ← config recipes for every workflow
│   ├── TROUBLESHOOTING.md            ← every "it's still asking" cause
│   ├── SECURITY.md                   ← real risks of full trust
│   ├── VERIFICATION.md               ← how to confirm the matcher logic yourself
│   └── FAQ.md                        ← common questions
├── tests/
│   └── Test-Script.ps1               ← installer smoke tests (28 assertions)
└── .github/                          ← CI, issue templates, dependabot
```

## 🎛️ Recipes

Pick the autonomy level that fits how you work. All recipes in [docs/RECIPES.md](docs/RECIPES.md).

### Maximum (this repo's default)
```jsonc
{
  "kiroAgent.agentAutonomy": "Autopilot",
  "kiroAgent.trustedTools": ["*"],
  "kiroAgent.trustedCommands": ["*"]
}
```

### Aggressive but bounded
Trust common dev commands, leave the rest gated. See [examples/settings.aggressive.json](examples/settings.aggressive.json).

### Conservative
Read-only trust, supervised file edits. See [examples/settings.conservative.json](examples/settings.conservative.json).

### Per-workspace override
Globally trust everything but lock down sensitive projects. See [examples/settings.workspace-override.json](examples/settings.workspace-override.json).

## 🔒 Safety First

`trustedCommands: ["*"]` means Kiro will run anything its agent decides will help, including:

- `rmdir /s /q`, `del /f /s /q`, `rm -rf`
- `git push --force`, `git reset --hard`, `git clean -fdx`
- Database mutations via MCP servers
- Outbound network requests with credentials

The agent's **system prompt** still has guardrails for the most dangerous categories, but IDE-level approval prompts are gone. **Use this in workspaces where you control the blast radius:** dev VMs, containers, projects under git, throwaway sandboxes.

For sensitive workspaces, drop a workspace `.vscode/settings.json` that overrides global trust. See [examples/settings.workspace-override.json](examples/settings.workspace-override.json).

Full risk and rollback details: [docs/SECURITY.md](docs/SECURITY.md).

## ↩️ Rollback

Every install creates a timestamped backup. To restore:

```powershell
# Windows / cross-platform
pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -Restore
```

```bash
# Unix
./scripts/enable-kiro-autonomy.sh --restore
```

Or manually copy the backup file (`settings.json.bak.YYYYMMDD-HHMMSS`) over `settings.json`.

## 📋 Requirements

- **Kiro IDE** (any recent version; verified against `kiro.kiro-agent` v0.3.433)
- **Windows:** PowerShell 5.1+ (built into Windows 10/11)
- **macOS / Linux:** PowerShell 7 (`pwsh`) **or** bash 4+

## 🤝 Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

Kinds of contributions especially appreciated:
- New recipe configs for specific stacks (Python, Rust, Go, .NET, mobile, etc.)
- Verified findings from new Kiro versions
- Translations of the guide
- Better examples and tutorials

## 🚢 Publishing your fork

If you cloned this repo and want to publish under your own GitHub account:

```powershell
# Replaces every rahul6396346 reference with your username
pwsh -File scripts/set-repo-owner.ps1 -Owner my-github-handle

# Then push
git init -b main
git add .
git commit -m "Initial release"
gh repo create kiro-autonomy --public --source=. --push
```

CI runs on first push and validates everything: JSON, Markdown, PowerShell, bash, plus end-to-end installer smoke tests on Linux/macOS/Windows.

## 📜 License

[MIT](LICENSE) — do whatever you want, no warranty.

## 🙏 Credits

Built by reverse-engineering Kiro's `kiro.kiro-agent` extension. Not affiliated with, endorsed by, or supported by AWS or the Kiro team. Kiro™ is a trademark of its respective owner. This is independent community documentation.

---

<div align="center">

**If this saved you a hundred clicks, consider starring the repo. ⭐**

[Report a bug](https://github.com/rahul6396346/kiro-autonomy/issues/new?template=bug_report.md) ·
[Request a feature](https://github.com/rahul6396346/kiro-autonomy/issues/new?template=feature_request.md) ·
[Read the guide](docs/GUIDE.md)

</div>
