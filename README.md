# dotfiles

Personal macOS configuration, version controlled.

Configs live in subdirectories here and are **symlinked** into their expected
locations in `$HOME`. Editing the symlinked file edits the file in this repo.

## Contents

| Tool | Repo path | Symlinked to |
|------|-----------|--------------|
| [Hammerspoon](https://www.hammerspoon.org/) | `hammerspoon/init.lua` | `~/.hammerspoon/init.lua` |
| Zsh | `zsh/zshrc` | `~/.zshrc` |
| Zsh | `zsh/zshenv` | `~/.zshenv` |
| Zsh | `zsh/zprofile` | `~/.zprofile` |
| [Ghostty](https://ghostty.org/) | `ghostty/config` | `~/.config/ghostty/config` |
| Git | `git/gitconfig` | `~/.gitconfig` |
| Git (PeakFS identity template) | `git/gitconfig-peakfs.example` | `~/.gitconfig-peakfs` (copy, untracked) |
| Git (Bupa client identity template) | `git/gitconfig-bupa.example` | `~/.gitconfig-bupa` (copy, untracked) |
| Git | `git/ignore` | `~/.config/git/ignore` |

`.zshrc` pulls in [Starship](https://starship.rs) (prompt), plus `fzf` and
`zoxide` (the `z` command) at the bottom — order matters there, keep
Starship last. It also expects oh-my-zsh and the `zsh-autosuggestions` /
`zsh-syntax-highlighting` plugins, which `install.sh` sets up automatically.

## Install on a new machine

```sh
git clone git@github.com:rajfta/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
brew bundle    # installs bat/eza/fzf/zoxide/starship/git-delta/ghostty/etc
```

`install.sh` is idempotent — it (re)creates the symlinks and backs up any
real file it would otherwise overwrite to `<file>.bak`. It also installs
oh-my-zsh and its two custom plugins if they're missing.

### Work laptop: git identity

`git/gitconfig` conditionally includes a separate identity file per work
context — `~/work/peakfs/` and `~/work/bupa/` each get their own, instead of
the personal identity:

```
[includeIf "gitdir:~/work/peakfs/"]
	path = ~/.gitconfig-peakfs
[includeIf "gitdir:~/work/bupa/"]
	path = ~/.gitconfig-bupa
```

`install.sh` seeds `~/.gitconfig-peakfs` / `~/.gitconfig-bupa` from the
`.example` templates in this repo **the first time only** (it never
overwrites an existing file). These are real, filled-in identity files
outside the repo — they're gitignored by name so real names/emails/signing
keys never get committed here. Fill them in after install:

```sh
$EDITOR ~/.gitconfig-peakfs   # adam.rajmuller@peakfs.io
$EDITOR ~/.gitconfig-bupa     # your mfmbupa/Azure DevOps client email
```

Add more `includeIf`/template pairs the same way for any additional client
or employer context. If you use different directories, update the
`includeIf "gitdir:..."` paths in `git/gitconfig` to match.

## Hammerspoon hotkeys

App launchers (`ctrl`+number):

- `ctrl+1` Chrome · `ctrl+2` VS Code · `ctrl+3` Ghostty
- `ctrl+4` cycles through open **Notion → Notes → Linear**
- `ctrl+5` cycles through open **Discord → WhatsApp → Telegram → Slack**

The cycle hotkeys only touch apps that are already running — nothing is
launched, and apps that are closed are skipped.

Window grid: `ctrl+g` enters a mode where `q w e / a s d / z x c` snap the
focused window to a 3×3 grid (chord cells to span), `return` to confirm,
`esc` to cancel.
