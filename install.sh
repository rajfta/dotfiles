#!/usr/bin/env bash
# Symlink dotfiles into their expected locations in $HOME.
# Idempotent: re-running is safe. Any pre-existing real file is backed up
# to <file>.bak before being replaced with a symlink.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# seed <template-in-repo> <target-in-home>
# One-time copy (never a symlink): the target holds real identity data that
# must never be tracked by this repo, so we don't touch it if it already exists.
seed() {
  local src="$DOTFILES_DIR/$1"
  local dest="$2"

  if [ -e "$dest" ]; then
    echo "ok:   $dest already exists, leaving it alone"
    return
  fi

  cp "$src" "$dest"
  echo "seed: $dest (from $1 — fill in your real identity)"
}

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

# .zshrc assumes oh-my-zsh plus these two custom plugins are present.
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "installing oh-my-zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

clone_plugin() {
  local repo="$1" dest="$HOME/.oh-my-zsh/custom/plugins/$2"
  if [ ! -d "$dest" ]; then
    git clone --depth=1 "$repo" "$dest"
  else
    echo "ok:   $dest already cloned"
  fi
}

clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting"

link "hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"
link "hammerspoon/wallpapers" "$HOME/.hammerspoon/wallpapers"

link "zsh/zshrc" "$HOME/.zshrc"
link "zsh/zshenv" "$HOME/.zshenv"
link "zsh/zprofile" "$HOME/.zprofile"

link "ghostty/config" "$HOME/.config/ghostty/config"

link "git/gitconfig" "$HOME/.gitconfig"
link "git/ignore" "$HOME/.config/git/ignore"

mkdir -p "$HOME/work/peakfs" "$HOME/work/bupa"
seed "git/gitconfig-peakfs.example" "$HOME/.gitconfig-peakfs"
seed "git/gitconfig-bupa.example" "$HOME/.gitconfig-bupa"

echo "Done."
echo
echo "Reminder: fill in real values in ~/.gitconfig-peakfs and ~/.gitconfig-bupa"
echo "(name, email, signingkey) before committing from ~/work/peakfs/ or ~/work/bupa/."
echo "These files are NOT tracked by this repo — only the .example templates are."
