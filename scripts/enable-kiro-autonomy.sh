#!/usr/bin/env bash
# ============================================================
#  Kiro Autonomy installer - macOS / Linux
#  Project: https://github.com/rahul6396346/kiro-autonomy
# ============================================================
#
# Configures Kiro IDE to run agent sessions end-to-end without
# Trust / Run / Reject prompts.
#
# Usage:
#   ./enable-kiro-autonomy.sh                    # apply maximum autonomy
#   ./enable-kiro-autonomy.sh --recipe aggressive
#   ./enable-kiro-autonomy.sh --dry-run
#   ./enable-kiro-autonomy.sh --restore
#
# Requires: bash 4+, and either jq (preferred) or python3 for JSON merging.

set -euo pipefail

# ----------------------------------------------------------------------
# Defaults
# ----------------------------------------------------------------------
RECIPE="maximum"
DRY_RUN=0
RESTORE=0
SETTINGS_PATH=""
QUIET=0

usage() {
    sed -n '4,18p' "$0" | sed 's/^# \{0,1\}//'
}

# ----------------------------------------------------------------------
# Parse args
# ----------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --recipe)        RECIPE="$2"; shift 2 ;;
        --recipe=*)      RECIPE="${1#*=}"; shift ;;
        --dry-run)       DRY_RUN=1; shift ;;
        --restore)       RESTORE=1; shift ;;
        --settings-path) SETTINGS_PATH="$2"; shift 2 ;;
        --quiet|-q)      QUIET=1; shift ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

case "$RECIPE" in
    maximum|aggressive|conservative|reset) ;;
    *) echo "Invalid --recipe '$RECIPE'. Use: maximum | aggressive | conservative | reset" >&2; exit 2 ;;
esac

# ----------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------
say()  { [[ $QUIET -eq 1 ]] || printf '%b\n' "$*"; }
ok()   { [[ $QUIET -eq 1 ]] || printf '\033[32m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

resolve_settings_path() {
    if [[ -n "$SETTINGS_PATH" ]]; then
        printf '%s\n' "$SETTINGS_PATH"
        return
    fi
    case "$(uname -s)" in
        Darwin)  printf '%s\n' "$HOME/Library/Application Support/Kiro/User/settings.json" ;;
        Linux)   printf '%s\n' "$HOME/.config/Kiro/User/settings.json" ;;
        MINGW*|MSYS*|CYGWIN*)
                 printf '%s\n' "${APPDATA:-$HOME/AppData/Roaming}/Kiro/User/settings.json" ;;
        *)       printf '%s\n' "$HOME/.config/Kiro/User/settings.json" ;;
    esac
}

# ----------------------------------------------------------------------
# Recipe payloads (as JSON snippets)
# ----------------------------------------------------------------------
recipe_json() {
    case "$1" in
        maximum) cat <<'JSON'
{
  "kiroAgent.agentAutonomy": "Autopilot",
  "kiroAgent.trustedTools": ["*"],
  "kiroAgent.trustedCommands": ["*"]
}
JSON
        ;;
        aggressive) cat <<'JSON'
{
  "kiroAgent.agentAutonomy": "Autopilot",
  "kiroAgent.trustedTools": ["*"],
  "kiroAgent.trustedCommands": [
    "node *", "npm *", "npx *", "pnpm *", "yarn *", "bun *",
    "python *", "py *", "pip *", "uv *", "uvx *", "poetry *",
    "go *", "cargo *", "rustc *",
    "java *", "javac *", "mvn *", "gradle *",
    "dotnet *", "make *", "cmake *",
    "git status", "git status -s", "git diff", "git diff --cached",
    "git log", "git log --oneline -20", "git show", "git branch",
    "git add *", "git commit *", "git pull", "git fetch",
    "git checkout *", "git switch *", "git stash", "git stash *",
    "ls *", "cat *", "grep *", "find *", "head *", "tail *",
    "docker *", "kubectl *", "terraform *",
    "curl *", "wget *", "ping *",
    "tsc *", "eslint *", "prettier *", "vitest *", "jest *", "pytest *"
  ]
}
JSON
        ;;
        conservative) cat <<'JSON'
{
  "kiroAgent.agentAutonomy": "Supervised",
  "kiroAgent.trustedTools": [
    "read_file", "read_files", "list_directory",
    "grep_search", "file_search",
    "remote_web_search", "web_fetch"
  ],
  "kiroAgent.trustedCommands": [
    "node --version", "npm --version", "python --version",
    "git status", "git diff",
    "ls", "cat *"
  ]
}
JSON
        ;;
        reset) cat <<'JSON'
{
  "kiroAgent.agentAutonomy": null,
  "kiroAgent.trustedTools": null,
  "kiroAgent.trustedCommands": null
}
JSON
        ;;
    esac
}

# ----------------------------------------------------------------------
# JSON merge backends
# ----------------------------------------------------------------------
merge_with_jq() {
    local path="$1" patch_json="$2"
    local existing="{}"
    if [[ -s "$path" ]]; then
        # Strip JSONC comments + trailing commas, fall back to {} if invalid
        existing=$(sed -E -e ':a' -e 's@/\*[^*]*\*+([^/*][^*]*\*+)*/@@g;ta' \
                            -e 's@//[^"\n]*$@@' \
                            -e 's/,\s*([}\]])/\1/g' "$path" \
                  | jq -c '. // {}' 2>/dev/null || echo "{}")
    fi

    local patch
    patch=$(printf '%s' "$patch_json" | jq 'with_entries(select(.value != null))')
    local removals
    removals=$(printf '%s' "$patch_json" | jq -c 'with_entries(select(.value == null)) | keys')

    # Remove keys whose patch value is null
    local merged
    merged=$(printf '%s' "$existing" | jq --argjson rm "$removals" 'del(.[$rm[]?])')
    merged=$(printf '%s' "$merged"   | jq --argjson p  "$patch"    '. * $p')

    # QoL defaults if missing and not reset
    if [[ "$RECIPE" != "reset" ]]; then
        merged=$(printf '%s' "$merged" | jq '
            if has("files.autoSave")                  then . else . + {"files.autoSave":"afterDelay"} end |
            if has("kiroAgent.enableTabAutocomplete") then . else . + {"kiroAgent.enableTabAutocomplete":true} end |
            if has("kiroAgent.enableCodebaseIndexing")then . else . + {"kiroAgent.enableCodebaseIndexing":true} end
        ')
    fi

    printf '%s\n' "$merged" | jq '.'
}

merge_with_python() {
    local path="$1" patch_json="$2"
    PATCH_JSON="$patch_json" RECIPE_NAME="$RECIPE" SETTINGS_PATH_FOR_PY="$path" \
    python3 - <<'PY'
import json
import os
import re

def strip_jsonc(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'(?m)^\s*//.*$', '', s)
    s = re.sub(r',(\s*[}\]])', r'\1', s)
    return s

path = os.environ['SETTINGS_PATH_FOR_PY']
patch = json.loads(os.environ['PATCH_JSON'])
recipe = os.environ['RECIPE_NAME']

existing = {}
if os.path.exists(path) and os.path.getsize(path) > 0:
    with open(path, 'r', encoding='utf-8') as f:
        try:
            existing = json.loads(strip_jsonc(f.read()))
        except json.JSONDecodeError:
            existing = {}

for k, v in patch.items():
    if v is None:
        existing.pop(k, None)
    else:
        existing[k] = v

if recipe != 'reset':
    existing.setdefault('files.autoSave', 'afterDelay')
    existing.setdefault('kiroAgent.enableTabAutocomplete', True)
    existing.setdefault('kiroAgent.enableCodebaseIndexing', True)

print(json.dumps(existing, indent=2, ensure_ascii=False))
PY
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
SETTINGS=$(resolve_settings_path)
say "Kiro user settings: $SETTINGS"

# --- Restore ---
if [[ $RESTORE -eq 1 ]]; then
    DIR=$(dirname "$SETTINGS")
    BASE=$(basename "$SETTINGS")
    BAK=""
    # Find newest backup file in a way that works on macOS + Linux.
    # shellcheck disable=SC2012
    if [[ -d "$DIR" ]]; then
        BAK=$(ls -1t "$DIR"/"${BASE}".bak.* 2>/dev/null | head -n 1 || true)
    fi
    if [[ -z "$BAK" ]]; then
        warn "No backup file found in $DIR"
        exit 1
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        say "Would restore from: $BAK"
        exit 0
    fi
    cp "$BAK" "$SETTINGS"
    ok "Restored from $(basename "$BAK")"
    say "Reload Kiro to apply: Ctrl+Shift+P -> Developer: Reload Window"
    exit 0
fi

mkdir -p "$(dirname "$SETTINGS")"

PATCH=$(recipe_json "$RECIPE")

if have jq; then
    MERGED=$(merge_with_jq "$SETTINGS" "$PATCH")
elif have python3; then
    MERGED=$(merge_with_python "$SETTINGS" "$PATCH")
else
    err "Need either 'jq' or 'python3' installed to merge JSON safely. Install one and rerun."
    exit 3
fi

if [[ $DRY_RUN -eq 1 ]]; then
    say "--- DRY RUN: would write the following ---"
    printf '%s\n' "$MERGED"
    exit 0
fi

# Backup
if [[ -f "$SETTINGS" ]]; then
    BAK="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$SETTINGS" "$BAK"
    say "Backed up: $BAK"
fi

# Write atomically
TMP=$(mktemp)
printf '%s\n' "$MERGED" > "$TMP"
mv "$TMP" "$SETTINGS"

ok "Kiro autonomy: $RECIPE applied."
say ""
say "Final step: reload Kiro to apply."
say "  Ctrl+Shift+P  ->  Developer: Reload Window"
say ""
say "To roll back: $0 --restore"
