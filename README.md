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
| Git (work identity templates) | `git/gitconfig-<context>.example` | `~/.gitconfig-<context>` (copy, untracked) |
| Git | `git/ignore` | `~/.config/git/ignore` |
| Claude Code (status line) | `claude/statusline-command.sh` | `~/.claude/statusline-command.sh` |
| Claude Code (global instructions) | `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Claude Code (theme) | `claude/themes/tailwind-theme.json` | `~/.claude/themes/tailwind-theme.json` |
| [Supacode](https://supacode.sh/) | `supacode/settings.json` | `~/.supacode/settings.json` (merged, not linked — see below) |

`~/.claude/settings.json` is **not** symlinked — Claude Code rewrites that file
itself (changing model, theme or effort via `/config` rewrites it, which would
clobber a symlink), and it holds machine-local plugin state. So on a new machine
add these two keys to it manually to wire up the status line and the theme:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
},
"theme": "custom:tailwind-theme"
```

The status line script renders two lines: `~/dir  branch*` (dir + git branch,
`*` = dirty working tree) and `Model · effort · ctx N%` (context % goes
green → yellow → bold-red as it drops).

`claude/CLAUDE.md` is global instructions loaded in **every** project — it tells
Claude which markdown constructs actually render in the terminal (`##` only, no
`---`, no footnotes, always tag code fences) and which to avoid.

`claude/themes/tailwind-theme.json` is a `base: dark` theme with TokyoNight
Moon–matched overrides, to sit with Ghostty's `TokyoNight Moon`. It restyles
Claude Code's *chrome* only — borders, spinners, diffs, subagent colours,
success/error/warning. The markdown body (headings, code-block backgrounds) has
no theme keys and can't be recoloured; that's what `claude/CLAUDE.md` works
around.

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

The personal identity in `git/gitconfig` (`rajfta@gmail.com`) is the default
everywhere. `git/gitconfig` then conditionally overrides it per work context,
so repos under `~/work/<context>/` commit as the right person:

```
[includeIf "gitdir:~/work/myedspace/"]
	path = ~/.gitconfig-myedspace
```

**Work context differs per machine**, so `git/gitconfig` lists an `includeIf`
for every context across all machines (git silently ignores an include whose
file doesn't exist), while `install.sh` only seeds the ones for the machine
it's running on. That's the `WORK_CONTEXTS` variable at the top of the script:

| Machine | Contexts |
|---------|----------|
| This laptop (default) | `myedspace` |
| Previous machine | `peakfs bupa` — `WORK_CONTEXTS="peakfs bupa" ./install.sh` |

Seeding is a one-time copy from the `.example` template — it never overwrites
an existing file. The copies are real, filled-in identity files outside the
repo; `.gitignore` covers `gitconfig-*` (excluding `*.example`) so real
names/emails/signing keys can never be committed here. Fill in after install:

```sh
$EDITOR ~/.gitconfig-myedspace   # name, work email, signingkey
```

To add a context: drop a `git/gitconfig-<name>.example` in the repo, add the
matching `includeIf "gitdir:~/work/<name>/"` block to `git/gitconfig`, and add
`<name>` to `WORK_CONTEXTS`.

## Hammerspoon hotkeys

App launchers (`ctrl`+number):

- `ctrl+1` Chrome · `ctrl+2` supacode · `ctrl+3` VS Code · `ctrl+4` Obsidian
- `ctrl+5` cycles through open **Discord → WhatsApp → Telegram → Slack**

The launcher hotkeys open the app if it isn't running. The cycle hotkey
(`ctrl+5`) only touches apps that are already running — nothing is launched,
and apps that are closed are skipped.

Window grid: `ctrl+g` enters a mode where `q w e / a s d / z x c` snap the
focused window to a 3×3 grid (chord cells to span), `return` to confirm,
`esc` to cancel.

## Supacode settings

Supacode is the daily driver, so its preferences and shortcut overrides live
here too. Unlike everything else in this repo it is **not** symlinked: Supacode
owns `~/.supacode/settings.json` and rewrites it as you work, and only part of
that file is portable. We track just the `global` block — every toggle in the
Settings UI, plus `shortcutOverrides` — and leave the machine-local parts
(`repositoryRoots`, `repositories`, `pinnedWorktreeIDs`, and the sibling
`sidebar.json` / `layouts.json` session state) alone.

**Quit Supacode before running either direction** — it holds settings in memory
and writes them back on quit, which would clobber an apply.

```sh
./supacode/sync-settings.sh pull    # after changing a setting in the UI, then commit
./supacode/sync-settings.sh apply   # on the other laptop (install.sh does this too)
```

`apply` merges: this machine's repo list survives, as does any settings key a
newer Supacode version added. `shortcutOverrides` is the exception — it is
replaced wholesale, so removing a rebind here actually removes it there.

Not covered: window geometry and onboarding flags in
`~/Library/Preferences/app.supabit.supacode.plist`. That is local state, not
configuration, so it stays per-machine.
