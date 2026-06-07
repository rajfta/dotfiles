# dotfiles

Personal macOS configuration, version controlled.

Configs live in subdirectories here and are **symlinked** into their expected
locations in `$HOME`. Editing the symlinked file edits the file in this repo.

## Contents

| Tool | Repo path | Symlinked to |
|------|-----------|--------------|
| [Hammerspoon](https://www.hammerspoon.org/) | `hammerspoon/init.lua` | `~/.hammerspoon/init.lua` |

## Install on a new machine

```sh
git clone git@github.com:rajfta/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

`install.sh` is idempotent — it (re)creates the symlinks and backs up any
real file it would otherwise overwrite to `<file>.bak`.

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
