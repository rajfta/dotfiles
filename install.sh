#!/usr/bin/env bash
# Symlink dotfiles into their expected locations in $HOME.
# Idempotent: re-running is safe. Any pre-existing real file is backed up
# to <file>.bak before being replaced with a symlink.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Work identity contexts to set up on THIS machine, space separated. Each name
# needs a git/gitconfig-<name>.example template in the repo and a matching
# [includeIf "gitdir:~/work/<name>/"] block in git/gitconfig. Machines differ,
# so override on the command line rather than editing this default:
#   WORK_CONTEXTS="peakfs bupa" ./install.sh
WORK_CONTEXTS="${WORK_CONTEXTS:-myedspace}"

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

link "claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
link "claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link "claude/themes/tailwind-theme.json" "$HOME/.claude/themes/tailwind-theme.json"

# Supacode owns ~/.supacode/settings.json and rewrites it as you use the app,
# so it can't be a symlink. Merge our tracked "global" block into it instead.
if [ -x "$DOTFILES_DIR/supacode/sync-settings.sh" ]; then
  "$DOTFILES_DIR/supacode/sync-settings.sh" apply
fi

for ctx in $WORK_CONTEXTS; do
  template="git/gitconfig-$ctx.example"
  if [ ! -e "$DOTFILES_DIR/$template" ]; then
    echo "skip: no $template in repo for work context '$ctx'"
    continue
  fi
  mkdir -p "$HOME/work/$ctx"
  seed "$template" "$HOME/.gitconfig-$ctx"
done

echo "Done."
echo
echo "Reminder: fill in real values (name, email, signingkey) in:"
for ctx in $WORK_CONTEXTS; do
  echo "  ~/.gitconfig-$ctx   -> used for repos under ~/work/$ctx/"
done
echo "These files are NOT tracked by this repo — only the .example templates are."
