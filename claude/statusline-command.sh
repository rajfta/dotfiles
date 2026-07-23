#!/bin/bash
# Claude Code status line (two lines):
#   line 1  ~/dir  branch*          <- where am I (dir bright, git dirty = *)
#   line 2  Model · effort · ctx N% <- session state (ctx colored by threshold)
#
# Source of truth lives in dotfiles; symlinked to ~/.claude/statusline-command.sh
# by install.sh. Referenced from ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }

input=$(cat)

DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
DIR_DISPLAY="${DIR/#$HOME/~}"

BRANCH=""
DIRTY=""
if [ -n "$DIR" ]; then
  BRANCH=$(git --no-optional-locks -C "$DIR" branch --show-current 2>/dev/null)
  if [ -n "$BRANCH" ] && [ -n "$(git --no-optional-locks -C "$DIR" status --porcelain 2>/dev/null | head -n1)" ]; then
    DIRTY="*"
  fi
fi

MODEL=$(echo "$input" | jq -r '.model.display_name // empty')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
REMAINING=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

RESET='\033[0m'
DIM='\033[2m'
BOLD_BLUE='\033[1;34m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
CYAN='\033[36m'
BOLD_RED='\033[1;31m'

# ---- line 1: location ----
line1="${BOLD_BLUE}${DIR_DISPLAY}${RESET}"
if [ -n "$BRANCH" ]; then
  line1="${line1}  ${GREEN}${BRANCH}${RESET}"
  [ -n "$DIRTY" ] && line1="${line1}${YELLOW}${DIRTY}${RESET}"
fi

# ---- line 2: session state ----
SEP="${DIM} · ${RESET}"
line2=""
[ -n "$MODEL" ] && line2="${MAGENTA}${MODEL}${RESET}"
if [ -n "$EFFORT" ]; then
  [ -n "$line2" ] && line2="${line2}${SEP}"
  line2="${line2}${CYAN}${EFFORT}${RESET}"
fi
if [ -n "$REMAINING" ]; then
  REMAINING_INT=$(printf '%.0f' "$REMAINING")
  if [ "$REMAINING_INT" -lt 20 ]; then
    CTX_COLOR="$BOLD_RED"
  elif [ "$REMAINING_INT" -lt 50 ]; then
    CTX_COLOR="$YELLOW"
  else
    CTX_COLOR="$GREEN"
  fi
  [ -n "$line2" ] && line2="${line2}${SEP}"
  line2="${line2}${CTX_COLOR}ctx ${REMAINING_INT}%${RESET}"
fi

printf "%b\n" "$line1"
[ -n "$line2" ] && printf "%b\n" "$line2"
