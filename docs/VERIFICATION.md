# Verification: Confirm This Yourself

Don't take any claim in this repo on faith. Here's how to reproduce every finding on your own machine. The whole point is that you can re-verify after Kiro updates.

## Locate the compiled extension

| OS | Path |
|---|---|
| Windows | `%LOCALAPPDATA%\Programs\Kiro\resources\app\extensions\kiro.kiro-agent\dist\extension.js` |
| macOS | `/Applications/Kiro.app/Contents/Resources/app/extensions/kiro.kiro-agent/dist/extension.js` |
| Linux | varies by install method, typically under `/opt/kiro/` or `/usr/share/kiro/` |

This is a single bundled JavaScript file, several MB in size. The variable names are minified but the structure is intact.

## Find the matcher function

### Windows (PowerShell)
```powershell
$f = "$env:LOCALAPPDATA\Programs\Kiro\resources\app\extensions\kiro.kiro-agent\dist\extension.js"
Select-String -Path $f -Pattern 'function P7\(' -Context 0,8
```

### macOS / Linux
```bash
F="/Applications/Kiro.app/Contents/Resources/app/extensions/kiro.kiro-agent/dist/extension.js"
grep -n -A 8 'function P7(' "$F"
```

### Expected output (v0.3.433)
```js
function P7(e19, t14, r26) {
  return r26.some((s18) => e19.includes(s18)) ? false : t14.includes("*") ? true : t14.some((s18) => {
    if (s18.endsWith(" *")) {
      const n25 = s18.slice(0, -2);
      return e19.startsWith(n25 + " ") || e19 === n25;
    }
    return e19 === s18;
  });
}
```

Confirms:
- `r26` is the denylist; if any pattern is contained in the command, return false
- `t14.includes("*")` — wildcard auto-trust
- Suffix `" *"` is the prefix-match indicator
- Otherwise exact-match

## Find the normalizer

```powershell
Select-String -Path $f -Pattern 'function g10\(' -Context 0,2
```

```bash
grep -n -A 2 'function g10(' "$F"
```

### Expected output
```js
function g10(e19) {
  return e19.trim().replace(/\s+/g, " ");
}
```

Confirms: both commands and patterns are trimmed and have internal whitespace collapsed before comparison. So `"  npm    install  "` matches `"npm install"`.

## Find the denylist source

```powershell
Select-String -Path $f -Pattern 'getCommandDenylist' -Context 0,1
```

```bash
grep -n -A 1 'getCommandDenylist' "$F"
```

### Expected output (v0.3.433)
```
getTrustedCommands: () => []
...
getCommandDenylist: () => []
```

Confirms: default denylist is empty. Nothing overrides the wildcard. May change in future versions.

## Find what settings keys are read

```powershell
Select-String -Path $f -Pattern 'trustedCommands|trustedTools|agentAutonomy' | Select-Object -First 20
```

```bash
grep -nE 'trustedCommands|trustedTools|agentAutonomy' "$F" | head -n 20
```

You'll see references to all three, both in declaration and use. Confirms they are the runtime keys, not just legacy strings.

## Verify the package manifest

```powershell
$pkg = "$env:LOCALAPPDATA\Programs\Kiro\resources\app\extensions\kiro.kiro-agent\package.json"
Get-Content $pkg | Select-String 'name|displayName|version' | Select-Object -First 3
```

```bash
PKG="/Applications/Kiro.app/Contents/Resources/app/extensions/kiro.kiro-agent/package.json"
grep -E '"name"|"displayName"|"version"' "$PKG" | head -n 3
```

Confirms which version of the agent extension you're running. The findings in this repo are pinned to v0.3.433. Anything substantially different needs re-verification.

## Check what configuration the manifest declares

```powershell
findstr /i "configuration" "$env:LOCALAPPDATA\Programs\Kiro\resources\app\extensions\kiro.kiro-agent\package.json"
```

```bash
grep -i 'configuration' "$PKG"
```

Look for the `configuration.properties` block. In v0.3.433 it only declares two settings:
- `kiroAgent.experiments`
- `kiroAgent.terminalCommandTimeout`

This proves what the README says: trust/autonomy keys are read at runtime but not declared in the manifest, so they don't appear in the Settings UI.

## Test the matcher behavior live

Once you have the matcher logic confirmed, test it in your settings:

1. Set `"kiroAgent.trustedCommands": ["echo *"]`
2. Reload the window
3. Have the agent run `echo hello world` — should run without prompting
4. Have the agent run `echo` (no args) — should also run; the prefix matcher allows the bare command
5. Have the agent run `dir` — should prompt; not in the trust list

Then try `["*"]`:
1. Reload the window
2. Have the agent run anything — should never prompt

## Reproduce the confusion-cause

To confirm the "settings cached at session start" claim:

1. Start a new chat session
2. Have the agent attempt a command
3. Click the dialog's **Trust** button to whitelist it
4. **Without reloading**, modify `settings.json` to remove that command from `trustedCommands`
5. Have the agent run a new instance of that command in the same session — it still runs without prompting because the session has the old (trusted) snapshot

Now reload the window and try again — the command will prompt because the session re-reads on startup.

This is why the installer always tells you to reload.

## Cross-check against this repo

If your verification finds different behavior than what this repo claims:

1. Note your Kiro version (Help → About) and `kiro.kiro-agent` extension version
2. Open an issue with:
   - The version numbers
   - The OS
   - The actual code excerpt that's different
   - What you expected based on this guide

We'll update the guide together.
