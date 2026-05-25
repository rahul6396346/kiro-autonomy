# Security: Risks and Mitigations of Full Autonomy

> This is the **risk discussion** document. For the vulnerability disclosure policy, see the repo-root `SECURITY.md`.

Going `trustedCommands: ["*"]` removes the IDE's "are you sure?" gate for shell commands. The agent is good but not infallible. Read this and decide whether the tradeoff fits your environment.

## What `["*"]` actually permits

With maximum autonomy applied, Kiro can — without asking — perform any action it deems useful. Examples it might justify to itself:

### File system
- `rm -rf <dir>` / `rmdir /s /q <dir>` / `del /f /s /q <pattern>`
- `Remove-Item -Recurse -Force`
- Creating files anywhere it has write access (`/etc/`, `~/.ssh/`, etc.)
- Modifying or deleting config files outside the project

### Git
- `git push --force` (rewriting remote history)
- `git reset --hard` (discarding local changes)
- `git clean -fdx` (deleting untracked files including build outputs)
- `git branch -D` (force-deleting branches)
- Committing with arbitrary author info

### Package managers
- `npm uninstall`, `pip uninstall -y`, `cargo remove`
- Installing arbitrary dependencies, including potentially malicious ones if it's misled by external content
- `npm publish` / `pypi upload` / `cargo publish` if credentials are configured

### Database / data
- Any SQL via MCP database servers, including `DROP`, `DELETE`, `TRUNCATE`
- Bulk updates without `WHERE` clauses
- Export of data to local files or remote endpoints

### Network
- `curl` / `wget` / `Invoke-WebRequest` to any URL, including with auth headers
- `ssh` and `scp` if keys are loaded
- DNS lookups, port scans

### System
- Editing the registry (Windows)
- `sudo` operations (Linux/macOS) if NOPASSWD is configured
- Starting/stopping services
- Scheduled tasks / cron jobs
- Environment variable changes via shell config

### Credentials
- Reading `.env`, `~/.aws/credentials`, `~/.kube/config`, `~/.npmrc` with auth tokens
- Sending credentials to outbound endpoints if instructed

## Agent-side guardrails (what's still in place)

The agent's system prompt has its own safety logic that survives `trustedCommands: ["*"]`:

- High-risk destructive operations should still get a confirmation message before execution
- Reading files likely to contain secrets is flagged
- Outbound transmission of project code, secrets, or user data to third-party endpoints requires explicit user request
- Production-affecting changes warrant explicit confirmation
- Hate speech, weapons, malware, child safety violations are refused outright

These are agent guidelines, not IDE enforcement. They depend on the model honoring its instructions and the agent prompt staying intact. They reduce risk; they don't eliminate it.

## Mitigations

Pick what fits your context.

### 1. Commit before letting the agent run
```bash
git add -A && git commit -m "checkpoint before agent run"
```
Or use a branch per task. If anything goes wrong: `git reset --hard HEAD~1`.

### 2. Use a sandbox
- **Docker container** with the project mounted
- **Dev VM** (UTM, VirtualBox, Hyper-V, Parallels)
- **WSL** (Windows) — separate filesystem from your Windows install
- **Codespaces / Gitpod** — completely remote

The agent's blast radius is limited to the sandbox.

### 3. Per-workspace overrides
Globally trust everything for personal projects, restrict trust on sensitive ones:

```json
// project/.vscode/settings.json
{
    "kiroAgent.agentAutonomy": "Supervised",
    "kiroAgent.trustedCommands": [],
    "kiroAgent.trustedTools": []
}
```

Workspace settings beat user settings.

### 4. Cap command runtime
```json
"kiroAgent.terminalCommandTimeout": 120000   // 2 minutes
```

A runaway script gets killed automatically.

### 5. Avoid running with elevated privileges
Don't run Kiro as administrator/root. Don't keep `sudo` credentials cached.

### 6. Watch the activity panel
Every command Kiro runs is shown in the chat. Stop it (`Esc`, the cancel button, or `Ctrl+C` in the chat panel) the moment you see something off.

### 7. Use `enableDebugLogs`
```json
"kiroAgent.enableDebugLogs": true
```

Output panel → `Kiro Agent` shows the agent's reasoning and approval decisions.

### 8. Audit-friendly recipes
For shared/work machines, prefer **Aggressive** over **Maximum**. Aggressive trusts common dev commands but still gates `rm`, `del`, `git push --force`, etc.

## Rollback

### File changes
- Click "Restore" on any chat checkpoint to revert all file changes from that turn forward
- Or `git reset --hard <commit>` if you committed

### Trust list
```powershell
pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -Restore
```

```bash
./scripts/enable-kiro-autonomy.sh --restore
```

Both restore the most recent backup created by the installer.

### Disable autopilot fast
- `Ctrl+M` (or `Cmd+M`) in chat — toggles supervised mode
- Or change the toggle in the chat input
- The agent immediately stops auto-approving file edits

### Stop a runaway session
- `Esc` in the chat panel
- Or click the red stop button
- Or `Ctrl+C` if focused in chat

### Reset trust completely
```powershell
pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -Recipe reset
```

This removes the three autonomy keys, returning to Kiro defaults (Supervised, no trust).

## What this repo does NOT do

- Does not patch Kiro itself
- Does not modify the extension binary
- Does not bypass agent-side safety guardrails
- Does not disable token limits or model rate limits
- Does not modify the system prompt
- Does not capture, log, or transmit any of your data anywhere

It's pure config — three keys in a JSON file.

## Threat model

| Threat | Mitigation in this repo |
|---|---|
| Installer modifies wrong file | Detects OS, validates path |
| Installer corrupts settings | JSONC parser tolerant of comments/trailing commas; backup before write |
| Installer overwrites user customizations | Merges into existing settings instead of replacing |
| Remote installer fetches malicious code | Pins to `main` branch on the official repo; users can pin to a tag |
| Backup files leak sensitive content | Backups stay on local filesystem only; `.gitignore` excludes them |
| Wildcard enables prompt injection from external content | Out of scope — this is a model/agent concern, not a settings concern |

If you find a security issue with the installer, see the repo-root `SECURITY.md` for disclosure.

## Questions to ask before applying Maximum

1. **If the agent ran `rm -rf .` right now, what would I lose?** If the answer is "nothing, it's all in git", you're good.
2. **Are there credentials on this machine that should never leave it?** If yes, prefer Aggressive or sandbox the agent.
3. **Is anyone else's data on this machine?** If yes, get their consent before granting an agent unattended access.
4. **Am I about to step away from the keyboard?** The agent shouldn't run unattended on a production machine. Use a dev environment for long-running sessions.

If those answers make you nervous, start with **Recipe C — Conservative** and work up.
