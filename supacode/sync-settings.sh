#!/usr/bin/env bash
# Move Supacode's portable settings between this repo and ~/.supacode.
#
# Supacode keeps everything in ~/.supacode/settings.json, but only the "global"
# block is portable: the rest (repositoryRoots, repositories, pinnedWorktreeIDs)
# is a list of checkouts that differs per machine, and sibling files
# (sidebar.json, layouts.json) are pure session state. So we sync just "global"
# -- which is where the Settings UI stores preferences and shortcut overrides.
#
#   ./sync-settings.sh pull    live config -> repo   (after changing settings in the UI)
#   ./sync-settings.sh apply   repo -> live config   (on a new machine; install.sh runs this)
#
# QUIT SUPACODE FIRST. It holds settings in memory and rewrites the file on
# change and on quit, so an apply against a running app gets clobbered.
set -euo pipefail

REPO_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/settings.json"
LIVE_FILE="$HOME/.supacode/settings.json"

command -v jq >/dev/null || { echo "sync-settings: jq is required (brew install jq)" >&2; exit 1; }

if pgrep -x supacode >/dev/null; then
  echo "warn: Supacode is running -- quit it first, or it will overwrite this." >&2
fi

case "${1:-}" in
  pull)
    [ -f "$LIVE_FILE" ] || { echo "sync-settings: no $LIVE_FILE to pull from" >&2; exit 1; }
    jq '{global: .global}' "$LIVE_FILE" > "$REPO_FILE"
    echo "pull: $LIVE_FILE -> supacode/settings.json"
    ;;
  apply)
    [ -f "$REPO_FILE" ] || { echo "sync-settings: no $REPO_FILE to apply" >&2; exit 1; }
    mkdir -p "$(dirname "$LIVE_FILE")"
    if [ ! -f "$LIVE_FILE" ]; then
      cp "$REPO_FILE" "$LIVE_FILE"
      echo "apply: created $LIVE_FILE from supacode/settings.json"
      exit 0
    fi
    # Merge rather than overwrite, so this machine's repositoryRoots and any
    # settings key added by a newer Supacode survive. shortcutOverrides is
    # replaced outright -- a merge could never remove a rebound shortcut.
    tmp="$(mktemp)"
    jq --slurpfile repo "$REPO_FILE" '
      .global = ((.global // {}) * $repo[0].global)
      | if ($repo[0].global | has("shortcutOverrides"))
        then .global.shortcutOverrides = $repo[0].global.shortcutOverrides
        else . end
    ' "$LIVE_FILE" > "$tmp"
    mv "$tmp" "$LIVE_FILE"
    echo "apply: supacode/settings.json -> $LIVE_FILE (global block merged)"
    ;;
  *)
    sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
