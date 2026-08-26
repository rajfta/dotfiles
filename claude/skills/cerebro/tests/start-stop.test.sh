#!/usr/bin/env bash
# Lifecycle test for start-server.sh / stop-server.sh.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../scripts"
TMP_BASE="${TMPDIR:-/tmp}"; TMP_BASE="${TMP_BASE%/}"
TMP="$(mktemp -d "$TMP_BASE/cerebro-startstop-XXXXXX")"
export CEREBRO_HOME="$TMP/home"
fail=0
ok()   { echo "ok   - $1"; }
bad()  { echo "FAIL - $1"; fail=1; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# 1. default location from --topic
cd "$TMP" && mkdir -p my-project && cd my-project
out="$("$SCRIPTS/start-server.sh" --topic rate-source)"
echo "$out"
expected="$CEREBRO_HOME/sessions/my-project/$(date +%Y-%m-%d)-rate-source"
check "session_dir defaults to ~/.cerebro/sessions/<project>/<date>-<topic>" \
  '[[ "$out" == *"\"session_dir\":\"$expected\""* ]]'
check "content/, state/, inbox/ exist" '[[ -d "$expected/content" && -d "$expected/state" && -d "$expected/inbox" ]]'
check "server-info written" '[[ -f "$expected/state/server-info" ]]'
check "inbox_dir in JSON" '[[ "$out" == *"\"inbox_dir\":\"$expected/inbox\""* ]]'
check ".last-port recorded per project" '[[ -f "$CEREBRO_HOME/sessions/my-project/.last-port" ]]'
port1="$(cat "$CEREBRO_HOME/sessions/my-project/.last-port")"

# 2. stop keeps the directory
echo '<h2>x</h2>' > "$expected/content/x.html"
"$SCRIPTS/stop-server.sh" "$expected" >/dev/null
check "server-stopped written" '[[ -f "$expected/state/server-stopped" ]]'
check "server-info removed" '[[ ! -f "$expected/state/server-info" ]]'
check "session dir and screens survive stop" '[[ -f "$expected/content/x.html" ]]'

# 3. restart on the same dir reuses the port
out2="$("$SCRIPTS/start-server.sh" --session-dir "$expected")"
check "restart with --session-dir reuses port" '[[ "$out2" == *"\"port\":$port1,"* ]]'
check "server-stopped cleared on restart" '[[ ! -f "$expected/state/server-stopped" ]]'
"$SCRIPTS/stop-server.sh" "$expected" >/dev/null

# 4. usage errors
err="$("$SCRIPTS/start-server.sh" 2>&1)"; check "no --topic and no --session-dir is an error" '[[ "$err" == *error* ]]'
err="$("$SCRIPTS/start-server.sh" --topic 'Bad Topic!' 2>&1)"; check "topic must be a kebab slug" '[[ "$err" == *error* ]]'

# 5. a garbled CEREBRO_OWNER_PID_HINT is rejected, not passed through.
# server.cjs does `ownerPid = CEREBRO_OWNER_PID ? Number(CEREBRO_OWNER_PID) : null`;
# a non-numeric hint becomes NaN, and ownerAlive()'s `if (!ownerPid) return true`
# then treats the owner as permanently alive — silently disabling the death
# watchdog for the process's whole life instead of erroring. Trace the script
# to confirm it falls back to the auto-detected grandparent PID (a real
# number) instead of forwarding the garbage string to node.
hint_dir="$TMP/hint-bad"
trace="$TMP/hint-trace.log"
CEREBRO_OWNER_PID_HINT="not-a-pid" bash -x "$SCRIPTS/start-server.sh" --session-dir "$hint_dir" >/dev/null 2>"$trace"
resolved_env="$(grep -oE 'CEREBRO_OWNER_PID=[^[:space:]]+' "$trace" | tail -1 | cut -d= -f2)"
check "garbled CEREBRO_OWNER_PID_HINT falls back to a numeric CEREBRO_OWNER_PID for node" \
  '[[ "$resolved_env" =~ ^[0-9]+$ ]]'
"$SCRIPTS/stop-server.sh" "$hint_dir" >/dev/null

# 6. start again on the same --session-dir WITHOUT stopping first: the old
# server must be fully reaped before the new one binds, so the port is reused
# (not a random fallback) and only one cerebro-server-id process survives.
restart_dir="$TMP/restart-no-stop"
out3="$("$SCRIPTS/start-server.sh" --session-dir "$restart_dir")"
port_first="$(printf '%s' "$out3" | sed -n 's/.*"port":\([0-9]*\).*/\1/p')"
out4="$("$SCRIPTS/start-server.sh" --session-dir "$restart_dir")"
port_second="$(printf '%s' "$out4" | sed -n 's/.*"port":\([0-9]*\).*/\1/p')"
check "restart without stopping first reuses the same port" \
  '[[ -n "$port_first" && "$port_first" == "$port_second" ]]'
server_id="$(cat "$restart_dir/state/server-instance-id" 2>/dev/null || true)"
survivor_count="$(pgrep -f "cerebro-server-id=$server_id" 2>/dev/null | wc -l | tr -d ' ')"
check "exactly one cerebro-server-id process survives the un-stopped restart" \
  '[[ "$survivor_count" == "1" ]]'
"$SCRIPTS/stop-server.sh" "$restart_dir" >/dev/null

rm -rf "$TMP"
exit $fail
