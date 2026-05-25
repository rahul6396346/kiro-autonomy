#!/usr/bin/env bash
# One-liner remote installer for Kiro Autonomy on macOS / Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/rahul6396346/kiro-autonomy/main/scripts/install.sh | bash
#
# With env vars (set them before the pipe):
#   curl -fsSL .../install.sh | KIRO_AUTONOMY_RECIPE=aggressive bash
#
# Available env vars:
#   KIRO_AUTONOMY_RECIPE         maximum | aggressive | conservative | reset
#   KIRO_AUTONOMY_RESTORE        any non-empty value triggers --restore
#   KIRO_AUTONOMY_DRYRUN         any non-empty value triggers --dry-run
#   KIRO_AUTONOMY_REPO_RAW       override raw repo URL
#   KIRO_AUTONOMY_SETTINGS_PATH  override settings.json path

set -euo pipefail

REPO_RAW="${KIRO_AUTONOMY_REPO_RAW:-https://raw.githubusercontent.com/rahul6396346/kiro-autonomy/main}"
SCRIPT_URL="$REPO_RAW/scripts/enable-kiro-autonomy.sh"

echo "=== Kiro Autonomy installer ==="
echo "Fetching: $SCRIPT_URL"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$SCRIPT_URL" -o "$TMP"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP" "$SCRIPT_URL"
else
    echo "Need curl or wget installed." >&2
    exit 2
fi

chmod +x "$TMP"

ARGS=()
[[ -n "${KIRO_AUTONOMY_RECIPE:-}" ]]        && ARGS+=(--recipe "$KIRO_AUTONOMY_RECIPE")
[[ -n "${KIRO_AUTONOMY_RESTORE:-}" ]]       && ARGS+=(--restore)
[[ -n "${KIRO_AUTONOMY_DRYRUN:-}" ]]        && ARGS+=(--dry-run)
[[ -n "${KIRO_AUTONOMY_SETTINGS_PATH:-}" ]] && ARGS+=(--settings-path "$KIRO_AUTONOMY_SETTINGS_PATH")

"$TMP" "${ARGS[@]}"
