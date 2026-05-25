# Troubleshooting

## "I set `trustedCommands: ['*']` but it's still asking"

Most common cause: the active chat session cached the trust list at startup. Settings reload, but in-flight tool approvals can use the snapshot.

**Fix:**
- New chat session: `Ctrl+T` (`Cmd+T` Mac) inside the chat panel
- Or: Command Palette → `Developer: Reload Window`

Other causes:
- **Workspace override.** Check `<project>/.vscode/settings.json` and `<project>/.kiro/settings/settings.json`. Workspace settings beat user settings.
- **JSON syntax error.** Trailing comma, missing bracket. Look for red squiggles in the editor.
- **Wrong key spelling.** JSON keys are case-sensitive. Must be `kiroAgent.trustedCommands`, not `kiroAgent.TrustedCommands` or `kiroagent.trustedcommands`.

## "Some tools still ask, others don't"

- A wildcard `["*"]` doesn't trust **MCP tools** that haven't been registered yet. After your first MCP server connects, reload to pick them up.
- The agent's per-call safety guardrails (built into the system prompt) can still pause for high-risk destructive operations even when settings say to auto-approve. This is intentional and not a settings bug.
- Some experimental tools may use a separate approval path. Update Kiro to the latest version.

## "Settings.json keeps getting reset / I see duplicates"

- Clicking the **Trust** button in a dialog **appends** the exact command string to `trustedCommands`. After many clicks the file gets noisy. The installer normalizes by replacing the trust arrays cleanly.
- Settings Sync can fight you. Disable it: Command Palette → `Settings Sync: Turn Off`.

## "The script says my JSON is invalid"

The installer strips JSONC comments and trailing commas before parsing. If it still fails:

```powershell
Get-Content "$env:APPDATA\Kiro\User\settings.json" | ConvertFrom-Json
```

Errors will tell you the line. Common issues:
- Unescaped backslashes in Windows paths (`C:\Users\...`). Use `\\`.
- Smart quotes copy-pasted from a webpage. Replace with straight `"`.
- `True`/`False` instead of `true`/`false`.

## "Reload Window doesn't show up"

- Command Palette: `Ctrl+Shift+P` (`Cmd+Shift+P` Mac)
- Type `Reload Window`
- It's also under `Developer: Reload Window` if you have dev mode enabled

## "I want to see the current effective trust list"

- Command Palette → `Preferences: Open User Settings (JSON)` → search `trustedCommands`
- Output panel → `Kiro Agent` (set `kiroAgent.enableDebugLogs: true` first) shows trust decisions per command

## "Installer fails on macOS / Linux"

The bash installer needs **either** `jq` **or** `python3`:

```bash
# macOS
brew install jq

# Ubuntu / Debian
sudo apt-get install jq

# Fedora / RHEL
sudo dnf install jq

# Arch
sudo pacman -S jq
```

Or use the PowerShell installer which has no extra deps once you have `pwsh`:

```bash
brew install --cask powershell      # macOS
sudo apt-get install -y powershell  # Ubuntu (via Microsoft repo)
```

## "Installer says my settings dir doesn't exist"

The script creates it automatically. If creation fails, the user running the script lacks write permission to the parent directory. Fix the perms or run as the right user.

## "Backup files are piling up"

Each run creates a `.bak.YYYYMMDD-HHMMSS` file. To clean up old backups:

```powershell
Get-ChildItem "$env:APPDATA\Kiro\User\settings.json.bak.*" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 5 |
    Remove-Item
```

```bash
ls -1t ~/.config/Kiro/User/settings.json.bak.* | tail -n +6 | xargs rm -f
```

## "Restore picks the wrong backup"

The `-Restore` flag uses the **most recent** backup by mtime. If you want to restore a specific older backup:

```powershell
Copy-Item -Force "$env:APPDATA\Kiro\User\settings.json.bak.20260520-091500" `
                 "$env:APPDATA\Kiro\User\settings.json"
```

## "Kiro started behaving differently after applying maximum"

That's expected. With maximum applied:
- The agent will run shell commands without asking
- It will edit files without per-hunk approval
- It will call tools (web fetch, MCP, etc.) immediately

If it feels too aggressive, switch to `Recipe -Recipe aggressive` or `conservative`. To see what it's about to do, set `kiroAgent.enableDebugLogs: true` and watch the Kiro Agent output channel.

## "I'm seeing a different matcher behavior than the docs claim"

Kiro updates often. Run the [verification commands](VERIFICATION.md) on your installed version. If the matcher logic differs:

1. Open an issue with the relevant code excerpt
2. Note your Kiro version (Help → About) and `kiro.kiro-agent` extension version
3. We'll update the guide

## "My organization's IT policy forbids running unsigned PowerShell scripts"

The script runs under `-ExecutionPolicy Bypass` for the single invocation, which doesn't change your machine's policy. If even that's blocked:

- Use the bash installer (works under WSL)
- Or paste the JSON manually into `settings.json` (see Recipe A in [RECIPES.md](RECIPES.md))
- Or sign the script yourself and run it through your org's process
