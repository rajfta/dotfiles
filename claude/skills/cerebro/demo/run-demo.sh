#!/usr/bin/env bash
# Start a Cerebro demo session and push one screen that uses every component.
# Usage: demo/run-demo.sh   (then open the printed URL; Ctrl-click in Ghostty)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# We're a wrapper script between the real caller and start-server.sh, which
# adds one extra process hop. Left alone, start-server.sh's own owner-PID
# detection would land on the ephemeral shell that ran this script rather
# than on whatever invoked it — and when a coding agent runs us as a single
# one-shot command, that ephemeral shell dies within moments, killing the
# server ~60s later regardless of whether the agent's session is still
# going. Resolve the correct owner ourselves (one hop further up than
# start-server.sh would look from here) and hand it over explicitly.
OWNER_PID_HINT="$(ps -o ppid= -p "$PPID" 2>/dev/null | tr -d ' ')"
if [[ -z "$OWNER_PID_HINT" || "$OWNER_PID_HINT" == "1" ]]; then
  OWNER_PID_HINT="$PPID"
fi
export CEREBRO_OWNER_PID_HINT="$OWNER_PID_HINT"

out="$("$HERE/../scripts/start-server.sh" --topic demo --open)"
echo "$out"
session="$(printf '%s' "$out" | sed -n 's/.*"session_dir":"\([^"]*\)".*/\1/p')"
[[ -n "$session" ]] || { echo "could not parse session_dir"; exit 1; }
cp "$HERE/pixel.png" "$session/inbox/"
cp "$HERE/tree.json" "$session/state/tree.json"
cp "$HERE/demo.html" "$session/content/demo-$(date +%H%M%S).html"
echo
echo "Session: $session"
echo "Stop:    $HERE/../scripts/stop-server.sh $session"
