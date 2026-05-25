# The Complete Kiro Autonomy Guide

A 14-section reference for everything related to making Kiro run without asking. Verified against `kiro.kiro-agent` extension v0.3.433.

> **Read [SECURITY.md](SECURITY.md) before applying.** Full autonomy means destructive commands run without confirmation.

## Table of Contents

1. [What I Actually Did to Fix This](#1-what-i-actually-did-to-fix-this)
2. [The One-Click Script](#2-the-one-click-script)
3. [What "Autonomy" Actually Means in Kiro](#3-what-autonomy-actually-means-in-kiro)
4. [The Three Layers of Approval](#4-the-three-layers-of-approval)
5. [Settings File Locations](#5-settings-file-locations)
6. [Every Relevant Setting Explained](#6-every-relevant-setting-explained)
7. [How `trustedCommands` Matching Actually Works](#7-how-trustedcommands-matching-actually-works)
8. [How `trustedTools` Works](#8-how-trustedtools-works)
9. [Recipes: From Cautious to Maximum Autonomy](#9-recipes-from-cautious-to-maximum-autonomy)
10. [Why Your Settings Don't Take Effect Immediately](#10-why-your-settings-dont-take-effect-immediately)
11. [Troubleshooting](#11-troubleshooting)
12. [The Token Limit Myth](#12-the-token-limit-myth)
13. [Safety, Risks, and Rollback](#13-safety-risks-and-rollback)
14. [Verification: How These Claims Were Confirmed](#14-verification-how-these-claims-were-confirmed)

## Does Kiro Expose This in the UI?

**No.** As of `kiro.kiro-agent` v0.3.433:

- The Kiro Settings UI exposes only two `kiroAgent.*` settings: `experiments` and `terminalCommandTimeout`. Everything else has to be edited in JSON.
- The chat panel has a `Trust` button on each command popup that **appends** the exact command string to `trustedCommands`. There is no "trust everything forever" button anywhere in the UI.
- The Autopilot/Supervised toggle in the chat input only governs file-edit approval, not tool/command approval.

So the wildcard config in this guide is the only supported path to "agent never asks me anything." It's a documented config field (the matcher explicitly checks `trustedList.includes("*")`), it's just not surfaced as a UI option.

---

## 1. What I Actually Did to Fix This

The exact sequence the installer automates.

### Step 1 — Identified the right file
On Windows: `%APPDATA%\Kiro\User\settings.json`. Same JSON file the Settings UI writes to.

### Step 2 — Found the three relevant keys
Searched the compiled extension at `…\Programs\Kiro\resources\app\extensions\kiro.kiro-agent\dist\extension.js` for `trustedCommands`, `trustedTools`, and `agentAutonomy`. Confirmed:

- `kiroAgent.agentAutonomy` accepts `"Autopilot"` or `"Supervised"`
- `kiroAgent.trustedTools` is a string array, runtime treats `"*"` as "all tools"
- `kiroAgent.trustedCommands` is a string array, runtime explicitly checks `list.includes("*")`

### Step 3 — Wrote the wildcard config
```json
{
    "kiroAgent.agentAutonomy": "Autopilot",
    "kiroAgent.trustedTools": ["*"],
    "kiroAgent.trustedCommands": ["*"]
}
```

### Step 4 — Diagnosed why it appeared not to work the first time
Settings reload, but the **active chat session caches** the trust list at startup. The fix is a window reload (or a fresh chat session).

### Step 5 — Verified against the source
```js
function P7(cmd, trusted, denied) {
    if (denied.some(d => cmd.includes(d))) return false;
    if (trusted.includes("*")) return true;
    return trusted.some(t => /* prefix or exact */);
}
```

The denylist (`getCommandDenylist`) returns `[]` in this version, so nothing overrides the wildcard.

---

## 2. The One-Click Script

`scripts/Enable-KiroFullAutonomy.ps1` does everything in section 1 automatically. Cross-platform (Windows / macOS / Linux), idempotent (safe to run repeatedly), and non-destructive (creates a timestamped backup each run).

### What it does

1. Detects the OS and resolves the correct `settings.json` path
2. Reads existing settings, stripping JSONC comments and trailing commas
3. Creates a backup: `settings.json.bak.YYYYMMDD-HHMMSS`
4. Merges in the recipe keys (default: `maximum`)
5. Adds three quality-of-life defaults if missing
6. Writes back as UTF-8 without BOM
7. Prints what changed and the reload instructions

### Recipes available

| Recipe | Effect |
|---|---|
| `maximum` (default) | Trust everything, Autopilot |
| `aggressive` | Autopilot, all tools, common dev commands only |
| `conservative` | Supervised, read-only tools, minimal commands |
| `reset` | Remove the three autonomy keys entirely |

### Usage

```powershell
# Default (maximum)
pwsh -File scripts/Enable-KiroFullAutonomy.ps1

# A specific recipe
pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -Recipe aggressive

# Preview without writing
pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -DryRun

# Roll back
pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -Restore
```

### Bash equivalent (macOS / Linux without pwsh)

```bash
./scripts/enable-kiro-autonomy.sh
./scripts/enable-kiro-autonomy.sh --recipe aggressive
./scripts/enable-kiro-autonomy.sh --dry-run
./scripts/enable-kiro-autonomy.sh --restore
```

---

## 3. What "Autonomy" Actually Means in Kiro

Kiro has two **autonomy modes**:

| Mode | Behavior |
|---|---|
| **Autopilot** | Agent works end-to-end. Reads, writes, runs commands, calls tools without interrupting you. Revertable. |
| **Supervised** | Agent yields after each turn that contains file edits. Per-hunk accept/reject. |

Toggle: bottom-right of chat input, or `Ctrl+M` (`Cmd+M` on Mac) while focused in chat.

**Autopilot alone does not stop the Trust / Run / Reject prompts.** Those come from a separate approval layer.

---

## 4. The Three Layers of Approval

Every action passes through up to three gates:

### Layer 1 — Autonomy mode
Autopilot lets file edits land without per-hunk approval; Supervised stops on each.

### Layer 2 — Tool trust (`trustedTools`)
Controls which tools (web fetch, file write, MCP servers, etc.) auto-execute. Untrusted tools trigger an approval prompt.

### Layer 3 — Command trust (`trustedCommands`)
Controls which shell commands run without the Trust / Run / Reject popup.

To be **completely** autonomous you need all three: Autopilot mode + trust all tools + trust all commands.

---

## 5. Settings File Locations

### Windows
- **User (global):** `%APPDATA%\Kiro\User\settings.json` → `C:\Users\<you>\AppData\Roaming\Kiro\User\settings.json`
- **Workspace:** `<project>\.vscode\settings.json` or `<project>\.kiro\settings\settings.json`

### macOS
- **User:** `~/Library/Application Support/Kiro/User/settings.json`

### Linux
- **User:** `~/.config/Kiro/User/settings.json`

### Precedence (highest wins)
```
workspace .kiro/settings/settings.json  >  workspace .vscode/settings.json  >  user settings.json  >  defaults
```

### Related config files

| Path | Purpose |
|---|---|
| `%APPDATA%\Kiro\User\settings.json` | Main settings |
| `~/.kiro/settings/mcp.json` | User-level MCP servers |
| `<workspace>/.kiro/settings/mcp.json` | Workspace MCP servers |
| `~/.kiro/steering/*.md` | Steering rules (always-included context) |
| `~/.kiro/skills/*` | Custom skills |
| `<workspace>/.kiro/specs/<feature>/` | Spec workflow files |
| `<workspace>/.kiro/hooks/*.json` | Agent hooks |

---

## 6. Every Relevant Setting Explained

### Autonomy & approval

| Setting | Type | Values | Effect |
|---|---|---|---|
| `kiroAgent.agentAutonomy` | string | `"Autopilot"` / `"Supervised"` | Autopilot runs end-to-end. Supervised yields on file edits. |
| `kiroAgent.trustedTools` | string[] | tool names or `"*"` | Auto-approves listed tools. |
| `kiroAgent.trustedCommands` | string[] | command strings, prefixes with `" *"`, or `"*"` | Auto-approves listed shell commands. |

### Quality of life

| Setting | Effect |
|---|---|
| `kiroAgent.modelSelection` | Active model id, e.g. `"claude-opus-4.7"`, `"claude-sonnet-4.7"`. |
| `kiroAgent.enableTabAutocomplete` | Inline ghost-text completions in editor. |
| `kiroAgent.enableCodebaseIndexing` | Builds a repo embedding index for `@codebase` retrieval. |
| `kiroAgent.codeReferences.referenceTracker` | Records sources cited in suggestions. |
| `kiroAgent.enableDebugLogs` | Verbose logs in Output panel → `Kiro Agent`. |
| `kiroAgent.terminalCommandTimeout` | Number (ms). Cap how long any one terminal command can run. |
| `kiroAgent.experiments` | Object. Toggle experimental flags. |
| `files.autoSave` | VS Code setting. `"afterDelay"` recommended so the agent reads latest file content. |

### Things that look related but aren't real

- **`kiroAgent.trustedWorkspaces`** — does not exist
- **`kiroAgent.unlimitedTokens`** — does not exist (see §12)
- **`kiroAgent.autoApproveAll`** — does not exist (use the wildcard combo)

---

## 7. How `trustedCommands` Matching Actually Works

The matcher (decompiled):

```js
function matches(command, trusted, denied) {
    const norm = s => s.trim().replace(/\s+/g, " ");
    const cmd  = norm(command);
    const den  = denied.map(norm);
    const tru  = trusted.map(norm);

    if (den.some(d => cmd.includes(d))) return false;
    if (tru.includes("*")) return true;
    return tru.some(t => {
        if (t.endsWith(" *")) {
            const prefix = t.slice(0, -2);
            return cmd.startsWith(prefix + " ") || cmd === prefix;
        }
        return cmd === t;
    });
}
```

### Matching modes

| Pattern | Matches | Example |
|---|---|---|
| `"*"` | every command | `"*"` matches anything |
| `"<word> *"` | `<word>` followed by anything, or exactly `<word>` | `"git *"` matches `git push`, `git status -s`, `git`. NOT `gitk`. |
| `"<exact>"` | exact match (whitespace normalized) | `"npm install"` matches only `npm install` |

### Whitespace normalization
Both command and patterns get `s.trim().replace(/\s+/g, " ")`. So `"  npm    install  "` and `"npm install"` are equivalent.

### Denylist
Currently empty by default in v0.3.433 (`getCommandDenylist: () => []`), so denylist won't block your wildcards. Could change in future versions.

### Multi-line / chained commands
`&&`, `;`, `&`, and pipes are part of the command string. So `"node --version && npm --version"` is matched as one literal. With `"*"` this is irrelevant.

---

## 8. How `trustedTools` Works

Simpler than commands:

```js
function isToolTrusted(toolName) {
    const trusted = getSettings().trustedTools ?? [];
    return trusted.includes(toolName);
}
```

Plain `Array.includes`, plus an implicit allow for two safe built-ins (`web_fetch`, `remote_web_search`). The runtime treats `"*"` as "all tools" via the wrapping check.

### Safer tool list (recommended if not using `"*"`)
```json
"kiroAgent.trustedTools": [
    "web_fetch", "remote_web_search",
    "read_file", "read_files",
    "list_directory", "grep_search", "file_search",
    "fs_write", "fs_append", "str_replace",
    "execute_pwsh", "getDiagnostics", "readCode"
]
```

This trusts read/write/search/shell/diagnostics, but still asks for newer/unknown tools.

---

## 9. Recipes: From Cautious to Maximum Autonomy

See [RECIPES.md](RECIPES.md) for the full recipe library with rationale.

Files in `examples/`:
- `settings.maximum.json`
- `settings.aggressive.json`
- `settings.conservative.json`
- `settings.workspace-override.json`

---

## 10. Why Your Settings Don't Take Effect Immediately

The #1 source of confusion. The flow:

1. You change `settings.json`
2. Kiro re-reads the file ✅
3. **But** the active chat session may have already snapshotted the trust list when it started
4. So the next command in the same session still triggers the old approval dialog

### Fix
- Open a new chat session: `Ctrl+T` while focused in chat (`Cmd+T` Mac)
- Or fully reload the window: Command Palette → `Developer: Reload Window`

After reload, the new trust list is in force everywhere.

---

## 11. Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for the full list. Quick fixes:

- **"Still asking after I set `*`"** → Reload window (§10)
- **"Some tools still ask"** → MCP tools registered after the cache snapshot need a reload
- **"Settings keep getting reset"** → Clicking "Trust" in the dialog appends; check Settings Sync isn't fighting you
- **"It says invalid JSON"** → trailing commas; run the installer (handles JSONC)

---

## 12. The Token Limit Myth

There is **no** `kiroAgent.unlimitedTokens` or `kiroAgent.maxTokens` setting. Token limits are not a config knob.

| Concept | Source | User-controllable? |
|---|---|---|
| Per-response output cap | The model | No |
| Context window size | The model | Indirectly via `kiroAgent.modelSelection` |
| Conversation length before compaction | Auto-compacted by Kiro | No |
| Plan usage allowance (e.g. `51.75 / 1000`) | Your Kiro plan | Upgrade plan |

What you can do:
- Pick a model with a larger context window
- Let auto-compaction run; don't fight it
- Use steering files instead of pasting context
- Run heavy investigation in sub-agents (`invoke_sub_agent`)

What you cannot do:
- Disable token limits (server-enforced)
- Make the model output unbounded text

---

## 13. Safety, Risks, and Rollback

See [SECURITY.md](SECURITY.md) for the full discussion. Summary:

`trustedCommands: ["*"]` allows, without asking:
- File deletion (`rm -rf`, `del /f /s /q`, `rmdir /s /q`)
- Git destructive ops (`push --force`, `reset --hard`, `clean -fdx`)
- Database mutations via MCP servers
- Outbound network requests

The agent's system prompt has its own guardrails for the most dangerous ops, but those are agent-side, not IDE-side prompts.

### Mitigations
1. Commit before you let it run; git stash gives a restore point
2. Run in a sandbox (Docker, dev VM, WSL)
3. Use workspace overrides for sensitive projects
4. Set `kiroAgent.terminalCommandTimeout` non-null
5. Watch the activity panel; stop with `Esc`

### Rollback options
- **File changes:** click "Restore" on a chat checkpoint
- **Trust list:** run installer with `-Restore` or `--restore`
- **Disable autopilot:** `Ctrl+M`
- **Stop a runaway:** chat panel `Ctrl+C` or red stop button

---

## 14. Verification: How These Claims Were Confirmed

See [VERIFICATION.md](VERIFICATION.md) for reproducible commands you can run on your own machine.

Compiled extension path:
- Windows: `%LOCALAPPDATA%\Programs\Kiro\resources\app\extensions\kiro.kiro-agent\dist\extension.js`
- macOS: `/Applications/Kiro.app/Contents/Resources/app/extensions/kiro.kiro-agent/dist/extension.js`

Quick verification:

```powershell
$f = "$env:LOCALAPPDATA\Programs\Kiro\resources\app\extensions\kiro.kiro-agent\dist\extension.js"
Select-String -Path $f -Pattern 'function P7\(' -Context 0,8
Select-String -Path $f -Pattern 'function g10\(' -Context 0,2
Select-String -Path $f -Pattern 'getCommandDenylist' -Context 0,1
```

This reproduces the matcher logic, normalizer, and denylist findings.
