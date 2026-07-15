# Tools the configs in this repo actually depend on.
#
# This is a curated subset of everything installed on the source machine
# (see `brew bundle dump` for the full list) -- kept to what .zshrc,
# .gitconfig, and the Ghostty config reference directly, plus a few
# terminal essentials. Add more as you need them on the new machine.

# --- referenced directly by dotfiles in this repo ---
brew "bat"        # cat='bat' alias in zsh/zshrc
brew "eza"        # ll/lt aliases in zsh/zshrc
brew "fzf"        # eval "$(fzf --zsh)" in zsh/zshrc
brew "zoxide"      # the "z" command -- eval "$(zoxide init zsh)" in zsh/zshrc
brew "starship"    # eval "$(starship init zsh)" in zsh/zshrc
brew "git-delta"   # core.pager/delta settings in git/gitconfig
cask "ghostty"     # terminal itself, config in ghostty/config
cask "hammerspoon" # window management + per-Space wallpaper tint in hammerspoon/init.lua
cask "spaceman"    # menu-bar Space indicator (Rectangles style); configured via `defaults`

# --- general terminal tools, not referenced by config but commonly paired ---
brew "ripgrep"     # fast grep, pairs well with fzf
brew "fd"          # fast find
brew "gh"          # GitHub CLI
brew "tldr"        # quick command examples
