#!/usr/bin/env bash
# Move macOS app preferences between this repo and the live `defaults` domains.
#
# Some apps ship no config file to symlink -- they keep every preference in the
# macOS user defaults database. That made them invisible to this repo: a new
# machine got the app with factory settings, or (if the cask was missing from
# the Brewfile too) no app at all. This script tracks the portable half of
# those domains as a plist per app under macos/.
#
#   ./defaults.sh pull    live domains -> repo   (after changing settings in a UI)
#   ./defaults.sh apply   repo -> live domains   (on a new machine; install.sh runs this)
#
# QUIT THE APPS FIRST. macOS caches defaults in cfprefsd and an app rewrites
# its own domain on quit, so an apply against a running app gets clobbered.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Domains to track, as `defaults` domain names. Each becomes macos/<domain>.plist.
# An app that isn't installed yet is skipped by both directions -- add the cask
# to the Brewfile, configure it once in the UI, then `pull`.
#
# Suffix a domain with `:sandboxed` when the app is sandboxed. Those apps read
# and write preferences inside their own container, NOT ~/Library/Preferences,
# so a plain `defaults write <domain>` lands in a file the app never reads.
# Check before adding one:
#
#   codesign -d --entitlements - --xml /Applications/<App>.app \
#     | plutil -p - | grep app-sandbox
#
DOMAINS=(
  "dev.jaysce.Spaceman"          # menu-bar Space indicator: style + per-Space names
  "org.p0deje.Maccy:sandboxed"   # clipboard manager: history size, hotkey, appearance
)

# Top-level keys never worth tracking: per-machine state, not configuration.
# Matched as shell globs, so a trailing * covers a family of keys.
IGNORE_KEYS=(
  "SU*"                # Sparkle updater bookkeeping: last check time, launch count
  "NSWindow Frame*"    # remembered window geometry
  "NSStatusItem*"      # menu-bar item position -- depends on the other items present
  "NSNavLast*"         # last-used open/save panel directory
  "LastUsedVersion"    # app's own upgrade-detection marker
  "migrations"         # ditto: which one-off data migrations already ran
)

ignored() {
  local key="$1" glob
  for glob in "${IGNORE_KEYS[@]}"; do
    # shellcheck disable=SC2254  # $glob is intentionally a pattern, not a literal
    case "$key" in $glob) return 0 ;; esac
  done
  return 1
}

# Top-level keys of a plist, one per line. In plutil's xml1 output the root
# dict's own keys carry exactly one leading tab; keys nested inside a dict get
# two or more, so this deliberately ignores them -- a nested dict is copied
# whole, as the value of its top-level key.
top_level_keys() {
  plutil -convert xml1 -o - "$1" | sed -n $'s/^\t<key>\\(.*\\)<\\/key>$/\\1/p'
}

# Whichever of Maccy/Spaceman/... this domain belongs to, for the running check.
app_of_domain() { echo "${1##*.}"; }

# `defaults` takes either a domain name or a path to a plist, so a sandboxed
# app's container prefs file is addressed the same way as a normal domain.
# $1 is a DOMAINS entry, with its optional `:sandboxed` suffix still attached.
target_of_entry() {
  local domain="${1%%:*}"
  case "$1" in
    *:sandboxed)
      echo "$HOME/Library/Containers/$domain/Data/Library/Preferences/$domain.plist"
      ;;
    *) echo "$domain" ;;
  esac
}

warn_if_running() {
  local app; app="$(app_of_domain "$1")"
  if pgrep -x "$app" >/dev/null 2>&1; then
    echo "warn: $app is running -- quit it first, or it will overwrite this." >&2
  fi
}

case "${1:-}" in
  pull)
    for entry in "${DOMAINS[@]}"; do
      domain="${entry%%:*}"
      target="$(target_of_entry "$entry")"
      live="$(mktemp)"
      defaults export "$target" "$live" 2>/dev/null || true
      # A domain that doesn't exist exports as an empty dict, which is
      # indistinguishable from an app that has never been configured -- both
      # mean "nothing to track here yet".
      if [ -z "$(top_level_keys "$live")" ]; then
        echo "skip: $domain has no settings on this machine"
        rm -f "$live"
        continue
      fi

      warn_if_running "$domain"

      out="$REPO_DIR/$domain.plist"
      tmp="$(mktemp)"
      plutil -create xml1 "$tmp"
      kept=0 skipped=0
      while IFS= read -r key; do
        if ignored "$key"; then
          skipped=$((skipped + 1))
          continue
        fi
        # -extract/-insert round-trips the raw XML, so types survive: bools stay
        # bools, and a nested binary plist stored as <data> (Spaceman's
        # spaceNames) stays byte-identical.
        frag="$(plutil -extract "$key" xml1 -o - "$live")"
        plutil -insert "$key" -xml "$frag" "$tmp"
        kept=$((kept + 1))
      done < <(top_level_keys "$live")

      mv "$tmp" "$out"
      chmod 644 "$out"   # mktemp gives 0600; these are tracked files, not secrets
      rm -f "$live"
      echo "pull: $domain -> macos/$domain.plist ($kept keys, $skipped ignored)"
    done
    ;;

  apply)
    for entry in "${DOMAINS[@]}"; do
      domain="${entry%%:*}"
      target="$(target_of_entry "$entry")"
      src="$REPO_DIR/$domain.plist"
      if [ ! -f "$src" ]; then
        echo "skip: no macos/$domain.plist tracked yet"
        continue
      fi

      warn_if_running "$domain"

      # A sandboxed app that has never run has no container yet; create the
      # prefs directory so settings can be staged before its first launch.
      case "$entry" in *:sandboxed) mkdir -p "$(dirname "$target")" ;; esac

      # Key by key rather than `defaults import`, which replaces the whole
      # domain: this way anything the live domain holds that we don't track
      # (updater state, a key added by a newer version) survives untouched.
      written=0
      while IFS= read -r key; do
        ignored "$key" && continue
        frag="$(plutil -extract "$key" xml1 -o - "$src")"
        defaults write "$target" "$key" "$frag"
        written=$((written + 1))
      done < <(top_level_keys "$src")

      echo "apply: macos/$domain.plist -> $domain ($written keys)"
    done
    # cfprefsd caches prefs per domain and can write its cached copy back over
    # a file we just edited, so nudge it to re-read from disk.
    killall cfprefsd 2>/dev/null || true
    echo "note: relaunch the apps to pick the new values up."
    ;;

  *)
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
