# Frequently Asked Questions

## Is this an official Kiro feature?

No. This is an independent, community-maintained tool. Not affiliated with the Kiro team or AWS. It uses a real, working setting that the Kiro team chose not to expose in the UI. The setting is stable enough that the matcher's wildcard branch has existed across multiple versions, but no official support guarantee exists.

## Will this break Kiro?

No. Kiro reads `settings.json` like any other VS Code-derived editor. We're only setting documented keys with valid values. Worst case: you don't like the change and run the script with `-Restore` to roll back.

## Will this disable safety features?

It disables the **IDE-level approval prompts** for shell commands and tools. It does **not** disable:
- The agent's system-prompt safety guardrails
- Token limits / rate limits / plan quotas
- Workspace trust prompts (the "Do you trust this folder?" dialog)
- File permission checks at the OS level
- Any model-side content filtering

See [SECURITY.md](SECURITY.md) for the full risk discussion.

## Does this give the agent unlimited tokens?

No. There is no setting for unlimited tokens. Token limits come from the model and your Kiro plan, not from configuration. See section 12 of [GUIDE.md](GUIDE.md).

## Why isn't this in the Kiro Settings UI?

Best guess: the Kiro team wanted users to opt in deliberately by editing JSON, rather than seeing a "Trust everything" checkbox in a settings panel. A casual user who toggles a UI option might not understand the implications. By requiring a JSON edit, they ensure people who turn this on have at least read about what they're doing.

## Will Kiro remove the wildcard support in a future version?

It might. The matcher logic is implementation detail, not API. We pin the verified version in the docs (v0.3.433) and recommend users re-verify after Kiro updates using [VERIFICATION.md](VERIFICATION.md). If the wildcard breaks, we'll update the repo.

## What about Kiro Enterprise / managed deployments?

Some enterprise managed-settings configurations can lock specific keys. If your IT admin has locked `trustedCommands`, the user setting won't override the policy. Talk to your admin or use a personal machine.

## Can I use this without the script?

Yes. Open `settings.json`, paste:
```json
{
    "kiroAgent.agentAutonomy": "Autopilot",
    "kiroAgent.trustedTools": ["*"],
    "kiroAgent.trustedCommands": ["*"]
}
```
Reload window. Done.

The script is just a convenience that handles JSONC parsing, backups, OS detection, and merging into existing settings.

## Does this work with the Kiro CLI?

The Kiro CLI (`kiro-cli`) is a separate tool from the IDE. It has its own approval model. This repo is IDE-only.

## Does this work with Kiro on the web / Codespaces?

If the web/cloud version reads `settings.json` from the user storage in the same way, yes. The settings keys are the same. We haven't tested every distribution.

## What's the difference between "trustedTools" and "trustedCommands"?

| | trustedTools | trustedCommands |
|---|---|---|
| Controls | Agent tool calls (web fetch, MCP, file ops) | Shell command execution |
| Match style | Plain `Array.includes` | `g10`-normalized exact / prefix / wildcard |
| Wildcard | `["*"]` | `["*"]` |
| Prefix wildcard | Not supported | `"git *"` works |

## Does the wildcard apply to file operations Kiro does internally?

The agent uses tools (`fs_write`, `str_replace`, etc.) for file operations, not shell commands. So `trustedTools` controls those. With `trustedTools: ["*"]`, file edits proceed without prompts (combined with Autopilot mode for the per-hunk approval gate).

## Can I trust just file operations and not shell commands?

Yes:
```json
{
    "kiroAgent.agentAutonomy": "Autopilot",
    "kiroAgent.trustedTools": ["*"],
    "kiroAgent.trustedCommands": []
}
```

Tools auto-approve, but every shell command still pops the Trust dialog. Useful if you want unattended code editing but careful manual review of any command execution.

## Why is the installer in PowerShell instead of bash?

Cross-platform. PowerShell 7 runs on macOS, Linux, and Windows; bash doesn't run on stock Windows. We ship both: PowerShell as the primary, bash as fallback.

## Can I run the installer in CI?

Yes. It's idempotent and deterministic.

```yaml
# GitHub Actions example
- name: Configure Kiro autonomy
  run: pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -Recipe maximum -Quiet
```

But CI environments rarely run Kiro itself, so this is mostly useful for testing or pre-provisioning dev machines.

## Will my settings sync to other machines?

If you have VS Code Settings Sync enabled, yes — the modified `settings.json` will sync. Be aware that means **every machine on that account** gets full autonomy. If that's not what you want, disable Settings Sync or use workspace-level overrides.

## How do I share my recipe with my team?

Two options:
1. Commit a workspace `.vscode/settings.json` with your team's recipe; everyone gets it on clone
2. Share the recipe name (e.g. "we use Aggressive") and have everyone run the installer with `-Recipe aggressive`

## Does this work in remote SSH / dev container modes?

Settings on the remote side apply to the remote agent. So set the trust list in the remote `settings.json` (the same paths but on the remote machine).

## I broke my settings.json and Kiro won't start

Find the most recent backup and restore manually:

```powershell
Get-ChildItem "$env:APPDATA\Kiro\User\settings.json.bak.*" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
# Then copy that file over settings.json
```

Or delete `settings.json` entirely; Kiro will recreate it with defaults on next launch.

## How is this different from VS Code's `terminal.integrated.allowChords` etc.?

Those are VS Code settings about terminal UX. Kiro's `trustedCommands` is specific to the **agent's** tool-execution path. Different layer.

## Does this affect any non-Kiro VS Code extensions?

No. The keys are namespaced under `kiroAgent.*`. Other extensions don't read them.

## Why is the agent named `kiro.kiro-agent` but settings are `kiroAgent.*`?

Marketing vs. extension ID. The extension's internal name (used in commands and settings keys) is `kiroAgent`; the publisher.id (used by VS Code) is `kiro.kiro-agent`. They refer to the same thing.
