#!/usr/bin/env bash
# Move Claude Code's portable settings between this repo and ~/.claude.
#
# Claude Code rewrites ~/.claude/settings.json itself (/config, /plugin, model
# and effort changes), so it can't be a symlink -- and most of it is
# machine-local anyway. So we sync just the keys below: plugins, the
# marketplaces they come from, the status line and the theme.
#
#   ./sync-settings.sh pull    live config -> repo   (after /plugin install etc.)
#   ./sync-settings.sh apply   repo -> live config   (on a new machine; install.sh runs this)
#
# apply also installs any enabled plugin that isn't installed yet, so a fresh
# machine ends up with the same plugins without touching /plugin.
set -euo pipefail

REPO_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/settings.json"
LIVE_FILE="$HOME/.claude/settings.json"
KEYS='["enabledPlugins", "extraKnownMarketplaces", "statusLine", "theme"]'

command -v jq >/dev/null || { echo "sync-settings: jq is required (brew install jq)" >&2; exit 1; }

install_missing_plugins() {
  if ! command -v claude >/dev/null; then
    echo "skip: claude CLI not found, plugins will need /plugin install"
    return
  fi

  # A fresh ~/.claude doesn't know the official marketplace until the first
  # interactive run, so add it alongside the ones declared in settings.
  local have
  have="$(claude plugin marketplace list --json | jq -r '.[].name')"
  jq -r '(.extraKnownMarketplaces // {} | to_entries[]
          | select(.value.source.source == "github")
          | "\(.key) \(.value.source.repo)"),
         "claude-plugins-official anthropics/claude-plugins-official"' "$REPO_FILE" |
    while read -r name repo; do
      if grep -qx "$name" <<<"$have"; then
        echo "ok:   marketplace $name"
      else
        claude plugin marketplace add "$repo" || echo "fail: marketplace $name" >&2
      fi
    done

  # Only user-scope installs count: a plugin installed for one project only
  # still needs a user-scope install to be on everywhere.
  have="$(claude plugin list --json | jq -r '.[] | select(.scope == "user") | .id')"
  jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$REPO_FILE" |
    while read -r id; do
      case "$id" in *@builtin) continue ;; esac
      if grep -qx "$id" <<<"$have"; then
        echo "ok:   plugin $id"
      else
        claude plugin install "$id" --scope user || echo "fail: plugin $id" >&2
      fi
    done
}

case "${1:-}" in
  pull)
    [ -f "$LIVE_FILE" ] || { echo "sync-settings: no $LIVE_FILE to pull from" >&2; exit 1; }
    jq --argjson keys "$KEYS" 'with_entries(select(.key as $k | $keys | index($k)))' \
      "$LIVE_FILE" > "$REPO_FILE"
    echo "pull: $LIVE_FILE -> claude/settings.json"
    ;;
  apply)
    [ -f "$REPO_FILE" ] || { echo "sync-settings: no $REPO_FILE to apply" >&2; exit 1; }
    mkdir -p "$(dirname "$LIVE_FILE")"
    if [ ! -f "$LIVE_FILE" ]; then
      cp "$REPO_FILE" "$LIVE_FILE"
      echo "apply: created $LIVE_FILE from claude/settings.json"
    else
      # Deep merge, so this machine's other settings and any extra plugins
      # enabled only here survive.
      tmp="$(mktemp)"
      jq --slurpfile repo "$REPO_FILE" '. * $repo[0]' "$LIVE_FILE" > "$tmp"
      mv "$tmp" "$LIVE_FILE"
      echo "apply: claude/settings.json -> $LIVE_FILE (merged)"
    fi
    install_missing_plugins
    ;;
  *)
    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
