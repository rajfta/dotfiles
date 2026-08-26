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

rm -rf "$TMP"
exit $fail
