#!/usr/bin/env bash
# Symlink dotfiles into their expected locations in $HOME.
# Idempotent: re-running is safe. Any pre-existing real file is backed up
# to <file>.bak before being replaced with a symlink.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# link <source-in-repo> <target-in-home>
link() {
  local src="$DOTFILES_DIR/$1"
  local dest="$2"

  if [ ! -e "$src" ]; then
    echo "skip: $src does not exist in repo"
    return
  fi

  mkdir -p "$(dirname "$dest")"

  # Already pointing where we want? Nothing to do.
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "ok:   $dest -> $src"
    return
  fi

  # A real file/dir or wrong symlink is in the way — back it up.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mv "$dest" "$dest.bak"
    echo "back: $dest -> $dest.bak"
  fi

  ln -s "$src" "$dest"
  echo "link: $dest -> $src"
}

link "hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"

echo "Done."
