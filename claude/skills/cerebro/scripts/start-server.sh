#!/usr/bin/env bash
# Start the Cerebro server and output connection info
# Usage: start-server.sh (--topic <kebab-slug> | --session-dir <path>) [--open] [--host <bind-host>] [--url-host <display-host>] [--idle-timeout-minutes <n>] [--foreground|--background]
#
# New session: --topic creates <CEREBRO_HOME or ~/.cerebro>/sessions/<basename $PWD>/<YYYY-MM-DD>-<topic>/{content,inbox,state}.
# Restart:     --session-dir <that path> reuses the same port and key so the open tab reconnects.
#
# Options:
#   --host <bind-host>    Host/interface to bind (default: 127.0.0.1).
#                         Use 0.0.0.0 in remote/containerized environments.
#   --url-host <host>     Hostname shown in returned URL JSON.
#   --idle-timeout-minutes <n>  Shut down after n minutes idle (default 240 = 4h).
#   --open                Auto-open the browser on the first screen.
#   --foreground          Run server in the current terminal (no backgrounding).
#   --background          Force background mode (overrides Codex auto-foreground).
#
# CEREBRO_OWNER_PID_HINT (env var) — for wrapper scripts only: overrides the
# auto-detected owner PID used by the death watchdog (see comment above
# OWNER_PID below).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Capture the caller's project before any cd: the project slug is its basename.
PROJECT_SLUG="$(basename "$PWD")"
CEREBRO_HOME="${CEREBRO_HOME:-$HOME/.cerebro}"

# Parse arguments
TOPIC=""
SESSION_DIR=""
FOREGROUND="false"
FORCE_BACKGROUND="false"
BIND_HOST="127.0.0.1"
URL_HOST=""
IDLE_TIMEOUT_MINUTES=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --topic)        TOPIC="$2"; shift 2 ;;
    --session-dir)  SESSION_DIR="$2"; shift 2 ;;
    --host)         BIND_HOST="$2"; shift 2 ;;
    --url-host)     URL_HOST="$2"; shift 2 ;;
    --idle-timeout-minutes) IDLE_TIMEOUT_MINUTES="$2"; shift 2 ;;
    --open)         export CEREBRO_OPEN=1; shift ;;
    --foreground|--no-daemon) FOREGROUND="true"; shift ;;
    --background|--daemon)    FORCE_BACKGROUND="true"; shift ;;
    *) echo "{\"error\": \"Unknown argument: $1\"}"; exit 1 ;;
  esac
done

if [[ -z "$SESSION_DIR" && -z "$TOPIC" ]]; then
  echo '{"error": "Pass --topic <kebab-slug> (new session) or --session-dir <path> (restart)"}'
  exit 1
fi
if [[ -n "$TOPIC" && ! "$TOPIC" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo '{"error": "--topic must be a kebab-case slug, e.g. rate-source"}'
  exit 1
fi

if [[ -z "$URL_HOST" ]]; then
  if [[ "$BIND_HOST" == "127.0.0.1" || "$BIND_HOST" == "localhost" ]]; then
    URL_HOST="localhost"
  else
    URL_HOST="$BIND_HOST"
  fi
fi

if [[ -n "$IDLE_TIMEOUT_MINUTES" ]]; then
  if ! [[ "$IDLE_TIMEOUT_MINUTES" =~ ^[0-9]+$ ]] || [[ "$IDLE_TIMEOUT_MINUTES" -lt 1 ]]; then
    echo "{\"error\": \"--idle-timeout-minutes must be a positive integer\"}"
    exit 1
  fi
  export CEREBRO_IDLE_TIMEOUT_MS=$(( IDLE_TIMEOUT_MINUTES * 60 * 1000 ))
fi

is_windows_like_shell() {
  case "${OSTYPE:-}" in
    msys*|cygwin*|mingw*) return 0 ;;
  esac
  if [[ -n "${MSYSTEM:-}" ]]; then
    return 0
  fi
  local uname_s
  uname_s="$(uname -s 2>/dev/null || true)"
  case "$uname_s" in
    MSYS*|MINGW*|CYGWIN*) return 0 ;;
  esac
  return 1
}

if [[ -n "${CODEX_CI:-}" && "$FOREGROUND" != "true" && "$FORCE_BACKGROUND" != "true" ]]; then
  FOREGROUND="true"
fi
if [[ "$FOREGROUND" != "true" && "$FORCE_BACKGROUND" != "true" ]]; then
  if is_windows_like_shell; then
    FOREGROUND="true"
  fi
fi

# Session files (server.log, server-info, .last-token) embed the session key —
# keep everything this script and the server create owner-only.
umask 077

# Session directory: explicit --session-dir (restart), else deterministic
# <home>/sessions/<project>/<date>-<topic>. Reusing an existing dir is fine —
# the newest screen wins and the tab reconnects.
PROJECT_ROOT="$CEREBRO_HOME/sessions/$PROJECT_SLUG"
if [[ -z "$SESSION_DIR" ]]; then
  SESSION_DIR="$PROJECT_ROOT/$(date +%Y-%m-%d)-$TOPIC"
else
  PROJECT_ROOT="$(dirname "$SESSION_DIR")"
fi
# Persist the bound port and key per project so a restart reuses them and an
# already-open browser tab reconnects to the same URL with a valid cookie.
export CEREBRO_PORT_FILE="$PROJECT_ROOT/.last-port"
export CEREBRO_TOKEN_FILE="$PROJECT_ROOT/.last-token"

STATE_DIR="${SESSION_DIR}/state"
PID_FILE="${STATE_DIR}/server.pid"
LOG_FILE="${STATE_DIR}/server.log"
SERVER_ID_FILE="${STATE_DIR}/server-instance-id"

mkdir -p "${SESSION_DIR}/content" "${SESSION_DIR}/inbox" "$STATE_DIR"
rm -f "${STATE_DIR}/server-stopped"

# Capture the OUTGOING server's id (if any) before we overwrite the id file
# with a new one below — we need it to prove the PID in server.pid really is
# that prior server, same as stop-server.sh's own check.
OLD_SERVER_ID=""
if [[ -f "$SERVER_ID_FILE" ]]; then
  OLD_SERVER_ID="$(tr -d '\r\n' < "$SERVER_ID_FILE" 2>/dev/null || true)"
fi

SERVER_ID=""
if [[ -r /dev/urandom ]]; then
  SERVER_ID="$(od -An -N24 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' || true)"
fi
if ! [[ "$SERVER_ID" =~ ^[A-Za-z0-9_-]{32,64}$ ]]; then
  SERVER_ID="$(printf '%08x%08x%08x%08x' "$$" "$(date +%s)" "${RANDOM:-0}" "${RANDOM:-0}")"
fi
printf '%s\n' "$SERVER_ID" > "$SERVER_ID_FILE"
chmod 600 "$SERVER_ID_FILE" 2>/dev/null || true

# Command line of a PID, POSIX /proc where available else ps (mirrors stop-server.sh).
old_server_command_line_for_pid() {
  local pid="$1"
  if [[ -r "/proc/$pid/cmdline" ]]; then
    tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null || true
    return 0
  fi
  ps -ww -p "$pid" -o command= 2>/dev/null || ps -f -p "$pid" 2>/dev/null | sed '1d' || true
}

# True if $1 is alive and its command line proves it is a Cerebro server for
# this session: carrying the exact prior --cerebro-server-id= when we know it,
# or (id file was missing/unreadable) any --cerebro-server-id= flag at all.
# Never signal a PID that fails this — a stale pid file may point at an
# unrelated process after a reboot or PID wraparound.
pid_is_cerebro_server() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null || return 1
  local command_line
  command_line="$(old_server_command_line_for_pid "$pid")"
  [[ -n "$command_line" ]] || return 1
  if [[ -n "$OLD_SERVER_ID" ]]; then
    local expected_arg="--cerebro-server-id=$OLD_SERVER_ID"
    case "$command_line" in
      *"$expected_arg"*) return 0 ;;
      *) return 1 ;;
    esac
  else
    case "$command_line" in
      *"--cerebro-server-id="*) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

# Kill any existing server, and wait for it to actually be gone before we bind
# the same port — otherwise a restart can race the old process off a port it
# still holds and land on a random fallback port instead of reusing it.
if [[ -f "$PID_FILE" ]]; then
  old_pid=$(cat "$PID_FILE")
  if pid_is_cerebro_server "$old_pid"; then
    kill "$old_pid" 2>/dev/null || true
    for _ in {1..20}; do
      kill -0 "$old_pid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$old_pid" 2>/dev/null; then
      kill -9 "$old_pid" 2>/dev/null || true
      sleep 0.1
    fi
  fi
  rm -f "$PID_FILE"
fi

cd "$SCRIPT_DIR" || exit 1

# Resolve the harness PID (grandparent of this script).
# $PPID is the ephemeral shell the harness spawned to run us — it dies
# when this script exits. The harness itself is $PPID's parent.
#
# A wrapper script (e.g. demo/run-demo.sh) that execs us adds one more
# process hop, which would make the grandparent resolve to that same
# ephemeral shell instead of the real harness. Such a wrapper can pass
# its own correctly-resolved value through CEREBRO_OWNER_PID_HINT to
# skip our recomputation.
#
# CEREBRO_OWNER_PID_HINT is trusted operator/wrapper input, not validated
# for *correctness* beyond "looks like a live PID": it must name the
# process whose death should stop this server (normally the coding-agent
# harness). We only guard against a garbled hint silently disabling the
# watchdog (see server.cjs's ownerAlive()/`if (ownerPid)` gates); a
# well-formed but wrong PID still re-couples server lifetime to whatever
# that PID is, with the idle timeout as the only backstop — that can't be
# caught here.
OWNER_PID_HINT="${CEREBRO_OWNER_PID_HINT:-}"
if [[ "$OWNER_PID_HINT" =~ ^[0-9]+$ && "$OWNER_PID_HINT" != "1" ]] && kill -0 "$OWNER_PID_HINT" 2>/dev/null; then
  OWNER_PID="$OWNER_PID_HINT"
else
  OWNER_PID="$(ps -o ppid= -p "$PPID" 2>/dev/null | tr -d ' ')"
  if [[ -z "$OWNER_PID" || "$OWNER_PID" == "1" ]]; then
    OWNER_PID="$PPID"
  fi
fi

# Windows/MSYS2: Node.js cannot see POSIX PIDs from the MSYS2 namespace.
# Passing a PID node cannot verify causes server to log owner-pid-invalid
# and self-terminate at the 60-second lifecycle check. Clear it so the
# watchdog is disabled and the idle timeout becomes the only shutdown trigger.
if is_windows_like_shell; then
  OWNER_PID=""
fi

# Foreground mode for environments that reap detached/background processes.
if [[ "$FOREGROUND" == "true" ]]; then
  env CEREBRO_DIR="$SESSION_DIR" CEREBRO_HOST="$BIND_HOST" CEREBRO_URL_HOST="$URL_HOST" CEREBRO_OWNER_PID="$OWNER_PID" node server.cjs "--cerebro-server-id=$SERVER_ID" &
  SERVER_PID=$!
  echo "$SERVER_PID" > "$PID_FILE"
  wait "$SERVER_PID"
  exit $?
fi

# Start server, capturing output to log file
# Use nohup to survive shell exit; disown to remove from job table
nohup env CEREBRO_DIR="$SESSION_DIR" CEREBRO_HOST="$BIND_HOST" CEREBRO_URL_HOST="$URL_HOST" CEREBRO_OWNER_PID="$OWNER_PID" node server.cjs "--cerebro-server-id=$SERVER_ID" > "$LOG_FILE" 2>&1 &
SERVER_PID=$!
disown "$SERVER_PID" 2>/dev/null
echo "$SERVER_PID" > "$PID_FILE"

# Wait for server-started message (check log file)
for _ in {1..50}; do
  if grep -q "server-started" "$LOG_FILE" 2>/dev/null; then
    # Verify server is still alive after a short window (catches process reapers)
    alive="true"
    for _ in {1..20}; do
      if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        alive="false"
        break
      fi
      sleep 0.1
    done
    if [[ "$alive" != "true" ]]; then
      echo "{\"error\": \"Server started but was killed. Retry in a persistent terminal with: $SCRIPT_DIR/start-server.sh --session-dir $SESSION_DIR --host $BIND_HOST --url-host $URL_HOST --foreground\"}"
      exit 1
    fi
    grep "server-started" "$LOG_FILE" | head -1
    exit 0
  fi
  sleep 0.1
done

# Timeout - server didn't start
echo '{"error": "Server failed to start within 5 seconds"}'
exit 1
