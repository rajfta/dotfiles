# Cerebro Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A personal Claude Code skill, `cerebro`, that interrogates a decision grilling-style while a local browser tab shows the images, code shapes, diagrams and the decision tree the questions are about, and ends by writing a decision record.

**Architecture:** Fork the five-file visual-companion server from the `superpowers` plugin (MIT) into `~/dotfiles/claude/skills/cerebro/scripts/`, rename and de-brand it, redesign the frame into a two-pane page (persistent decision-tree sidebar rendered from `state/tree.json` + current screen), add an `/inbox/*` image route and a free-text note channel, and move session storage to `~/.cerebro/sessions/…`. Then write `SKILL.md` + `visual-guide.md` on top. The skill is symlinked into `~/.claude/skills/cerebro` by the dotfiles `install.sh`.

**Tech Stack:** Node 22 (dependency-free `http` + hand-rolled RFC 6455 WebSocket, `node:test`, global `WebSocket` client), Bash, plain HTML/CSS/JS, mermaid from CDN.

**Spec:** `~/dotfiles/claude/skills/cerebro/DESIGN.md`

## Global Constraints

- Nothing from this work is ever written inside a work repo (`~/work/**`). All files live in `~/dotfiles/claude/skills/cerebro/` (code) or `~/.cerebro/` (runtime state).
- Commits go to the `~/dotfiles` repo. Its message style is a plain imperative sentence, sentence case, no conventional-commit prefix, e.g. `Add brain command; route git HTTPS credentials through gh`. Do **not** push.
- No npm dependencies, no `package.json`. Tests run with `node --test`; shell tests are plain bash.
- The strings `brainstorm`, `Brainstorm`, `BRAINSTORM`, `superpowers`, `Superpowers`, `Prime Radiant`, `primeradiant` must not appear anywhere under `scripts/` after Task 2 (they may appear in `LICENSE-superpowers` and in `DESIGN.md`/`PLAN.md`).
- Attribution: `scripts/LICENSE-superpowers` holds the upstream MIT text; `server.cjs` opens with a one-line comment naming the origin.
- Every server route keeps the existing security posture: session key via `?key=`/cookie, constant-time compare, `securityHeaders()`, path-traversal guard for served files, WebSocket origin check.
- Source of the fork: `/Users/adamrajmuller/.claude/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/brainstorming/scripts/` (files: `server.cjs`, `frame-template.html`, `helper.js`, `start-server.sh`, `stop-server.sh`) and `LICENSE` two levels up from `skills/`.
- Test ports are fixed per test file so files can run concurrently: 47001 (smoke), 47002 (inbox), 47003 (tree), 47004 (events). Test dirs live under `$TMPDIR`/`os.tmpdir()`, never under the repo.

## File structure

```text
~/dotfiles/
  install.sh                               # +3 link lines
  README.md                                # +3 table rows
  claude/skills/
    grilling/SKILL.md                      # moved in from ~/.claude/skills (Task 1)
    grill-me/SKILL.md                      # moved in from ~/.claude/skills (Task 1)
    cerebro/
      DESIGN.md                            # exists
      PLAN.md                              # this file
      SKILL.md                             # Task 8 — stance, triggers, loop, ending
      visual-guide.md                      # Task 8 — markup, events, tree.json, decisions.md
      scripts/
        LICENSE-superpowers                # Task 1
        server.cjs                         # Tasks 1,2,4,5,6
        frame-template.html                # Tasks 1,2,5,6
        helper.js                          # Tasks 1,2,5,6
        start-server.sh                    # Tasks 1,2,3
        stop-server.sh                     # Tasks 1,2,3
      demo/
        tree.json                          # Task 7 — sample decision tree
        demo.html                          # Task 7 — one screen using every component
        pixel.png                          # Task 7 — 1×1 png for the gallery
        run-demo.sh                        # Task 7 — starts a session and pushes the demo
      tests/
        helpers.js                         # Task 2 — start server, fetch, ws, wait
        smoke.test.js                      # Task 2
        no-upstream-strings.test.js        # Task 2
        start-stop.test.sh                 # Task 3
        inbox.test.js                      # Task 4
        tree.test.js                       # Task 5
        helper-render.test.js              # Task 5
        events.test.js                     # Task 6
        frame.test.js                      # Task 6
```

Responsibilities: `server.cjs` = HTTP/WS/file-watch/session lifecycle only; `helper.js` = the browser client (reconnect, click/note capture, tree rendering); `frame-template.html` = layout + CSS; `start-server.sh`/`stop-server.sh` = process + directory lifecycle; `SKILL.md` = process; `visual-guide.md` = reference the skill points at.

---

### Task 1: Scaffold the skill in dotfiles and wire the symlinks

**Files:**
- Create: `~/dotfiles/claude/skills/cerebro/scripts/{server.cjs,frame-template.html,helper.js,start-server.sh,stop-server.sh,LICENSE-superpowers}` (verbatim copies)
- Move: `~/.claude/skills/grilling/` → `~/dotfiles/claude/skills/grilling/`, `~/.claude/skills/grill-me/` → `~/dotfiles/claude/skills/grill-me/`
- Modify: `~/dotfiles/install.sh` (after the three existing `link "claude/..."` lines)
- Modify: `~/dotfiles/README.md` (the table that has the `Claude Code (theme)` row)

**Interfaces:**
- Produces: `~/.claude/skills/cerebro` → symlink to `~/dotfiles/claude/skills/cerebro`; every later task edits files under `~/dotfiles/claude/skills/cerebro/`.

- [ ] **Step 1: Copy the upstream files and the license**

```bash
SRC=/Users/adamrajmuller/.claude/plugins/cache/claude-plugins-official/superpowers/6.3.0
DST=~/dotfiles/claude/skills/cerebro/scripts
mkdir -p "$DST"
cp "$SRC"/skills/brainstorming/scripts/{server.cjs,frame-template.html,helper.js,start-server.sh,stop-server.sh} "$DST"/
cp "$SRC"/LICENSE "$DST"/LICENSE-superpowers
chmod +x "$DST"/start-server.sh "$DST"/stop-server.sh
ls -la "$DST"
```

Expected: six files; the two `.sh` are executable.

- [ ] **Step 2: Move the two untracked skills into the repo**

```bash
mv ~/.claude/skills/grilling ~/dotfiles/claude/skills/grilling
mv ~/.claude/skills/grill-me ~/dotfiles/claude/skills/grill-me
ls ~/dotfiles/claude/skills
```

Expected: `cerebro  grill-me  grilling`.

- [ ] **Step 3: Add the link lines to install.sh**

In `~/dotfiles/install.sh`, directly after the line
`link "claude/themes/tailwind-theme.json" "$HOME/.claude/themes/tailwind-theme.json"`
insert:

```bash
link "claude/skills/cerebro" "$HOME/.claude/skills/cerebro"
link "claude/skills/grilling" "$HOME/.claude/skills/grilling"
link "claude/skills/grill-me" "$HOME/.claude/skills/grill-me"
```

- [ ] **Step 4: Add README rows**

In `~/dotfiles/README.md`, after the row
`| Claude Code (theme) | \`claude/themes/tailwind-theme.json\` | \`~/.claude/themes/tailwind-theme.json\` |`
add:

```markdown
| Claude Code (skill: cerebro) | `claude/skills/cerebro/` | `~/.claude/skills/cerebro` |
| Claude Code (skill: grilling) | `claude/skills/grilling/` | `~/.claude/skills/grilling` |
| Claude Code (skill: grill-me) | `claude/skills/grill-me/` | `~/.claude/skills/grill-me` |
```

- [ ] **Step 5: Run install.sh and verify the symlinks**

```bash
cd ~/dotfiles && WORK_CONTEXTS="" ./install.sh 2>&1 | grep -E 'skills|Done'
readlink ~/.claude/skills/cerebro ~/.claude/skills/grilling ~/.claude/skills/grill-me
```

Expected: three `link:` lines, then the three symlink targets under `/Users/adamrajmuller/dotfiles/claude/skills/`. (`WORK_CONTEXTS=""` skips the git-identity seeding; the `link` calls are idempotent.)

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add install.sh README.md claude/skills
git commit -m "Track Claude skills in dotfiles; scaffold cerebro from the superpowers companion (MIT)"
```

---

### Task 2: Rename brainstorm → cerebro and remove upstream branding

**Files:**
- Modify: `scripts/server.cjs`, `scripts/helper.js`, `scripts/frame-template.html`, `scripts/start-server.sh`, `scripts/stop-server.sh`
- Create: `tests/helpers.js`, `tests/smoke.test.js`, `tests/no-upstream-strings.test.js`

All paths in this task are relative to `~/dotfiles/claude/skills/cerebro/`.

**Interfaces:**
- Produces (env vars read by `server.cjs`): `CEREBRO_PORT`, `CEREBRO_PORT_FILE`, `CEREBRO_HOST`, `CEREBRO_URL_HOST`, `CEREBRO_DIR`, `CEREBRO_OWNER_PID`, `CEREBRO_TOKEN`, `CEREBRO_TOKEN_FILE`, `CEREBRO_OPEN`, `CEREBRO_OPEN_CMD`, `CEREBRO_IDLE_TIMEOUT_MS`, `CEREBRO_LIFECYCLE_CHECK_MS`.
- Produces: cookie name `cerebro-key-<port>`; sessionStorage key `cerebro-session-key`; process argv marker `--cerebro-server-id=<id>`; browser global `window.cerebro`.
- Produces (tests): `tests/helpers.js` exporting `startServer(port, dir, token, extraEnv)`, `waitForStarted(child)`, `get(port, token, path)`, `stop(child)`, `TOKEN`.

- [ ] **Step 1: Write the test helpers**

Create `tests/helpers.js`:

```js
const { spawn } = require('node:child_process');
const http = require('node:http');
const path = require('node:path');

const SERVER = path.join(__dirname, '..', 'scripts', 'server.cjs');
const TOKEN = 'cerebrotesttoken0123456789abcdef0123456789abcdef';

function startServer(port, dir, token = TOKEN, extraEnv = {}) {
  return spawn('node', [SERVER], {
    env: { ...process.env, CEREBRO_PORT: String(port), CEREBRO_DIR: dir, CEREBRO_TOKEN: token, ...extraEnv },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function waitForStarted(child, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    let out = '';
    const timer = setTimeout(() => reject(new Error('server did not start: ' + out)), timeoutMs);
    child.stdout.on('data', (c) => {
      out += c;
      const line = out.split('\n').find((l) => l.includes('"server-started"'));
      if (line) { clearTimeout(timer); resolve(JSON.parse(line)); }
    });
    child.stderr.on('data', (c) => { out += c; });
    child.on('exit', (code) => { clearTimeout(timer); reject(new Error('server exited ' + code + ': ' + out)); });
  });
}

function get(port, token, urlPath, headers = {}) {
  return new Promise((resolve, reject) => {
    const h = token ? { Cookie: `cerebro-key-${port}=${token}`, ...headers } : headers;
    http.get({ host: '127.0.0.1', port, path: urlPath, headers: h }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
    }).on('error', reject);
  });
}

function stop(child) {
  return new Promise((resolve) => {
    if (child.exitCode !== null) return resolve();
    child.once('exit', () => resolve());
    child.kill('SIGTERM');
    setTimeout(() => { try { child.kill('SIGKILL'); } catch (e) {} }, 1000).unref();
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

module.exports = { startServer, waitForStarted, get, stop, sleep, TOKEN };
```

- [ ] **Step 2: Write the failing smoke test**

Create `tests/smoke.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { startServer, waitForStarted, get, stop, TOKEN } = require('./helpers');

const PORT = 47001;

test('server starts with CEREBRO_* env, serves the frame under a cerebro cookie, and rejects no-key requests', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-smoke-'));
  const child = startServer(PORT, dir);
  try {
    const info = await waitForStarted(child);
    assert.equal(info.port, PORT);
    assert.match(info.url, /\?key=/);
    assert.equal(info.screen_dir, path.join(dir, 'content'));

    const denied = await get(PORT, null, '/');
    assert.equal(denied.status, 403);

    const ok = await get(PORT, TOKEN, '/');
    assert.equal(ok.status, 200);
    const body = ok.body.toString();
    assert.match(body, /Cerebro/);
    assert.doesNotMatch(body, /brainstorm/i);
    assert.doesNotMatch(body, /superpowers|prime ?radiant/i);
    assert.match(ok.headers['set-cookie'][0], new RegExp('^cerebro-key-' + PORT + '='));
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
```

- [ ] **Step 3: Write the failing no-upstream-strings test**

Create `tests/no-upstream-strings.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const SCRIPTS = path.join(__dirname, '..', 'scripts');
const FILES = ['server.cjs', 'frame-template.html', 'helper.js', 'start-server.sh', 'stop-server.sh'];
const FORBIDDEN = /brainstorm|superpowers|prime ?radiant/i;

for (const f of FILES) {
  test(`${f} carries no upstream brand strings`, () => {
    const lines = fs.readFileSync(path.join(SCRIPTS, f), 'utf-8').split('\n');
    const hits = lines.map((l, i) => (FORBIDDEN.test(l) ? `${i + 1}: ${l.trim()}` : null)).filter(Boolean);
    assert.deepEqual(hits, []);
  });
}
```

- [ ] **Step 4: Run both tests to verify they fail**

```bash
cd ~/dotfiles/claude/skills/cerebro && node --test tests/smoke.test.js tests/no-upstream-strings.test.js
```

Expected: FAIL — smoke test times out or gets a `brainstorm-key-` cookie (the server ignores `CEREBRO_PORT`, so it binds a random port); the strings test lists many hits.

- [ ] **Step 5: Mechanical rename across the five scripts**

```bash
cd ~/dotfiles/claude/skills/cerebro/scripts
sed -i '' \
  -e 's/BRAINSTORM_/CEREBRO_/g' \
  -e 's/brainstorm-key-/cerebro-key-/g' \
  -e 's/brainstorm-session-key/cerebro-session-key/g' \
  -e 's/--brainstorm-server-id/--cerebro-server-id/g' \
  -e 's/window\.brainstorm/window.cerebro/g' \
  -e 's/is_brainstorm_server/is_cerebro_server/g' \
  -e "s/id = 'bs-tombstone'/id = 'cerebro-tombstone'/" \
  server.cjs helper.js start-server.sh stop-server.sh
grep -n -i 'brainstorm\|superpowers\|radiant' server.cjs helper.js frame-template.html start-server.sh stop-server.sh
```

Expected: the remaining hits are only in comments/titles/branding, which the next steps remove by hand.

- [ ] **Step 6: Strip branding from server.cjs**

Edit `scripts/server.cjs`:

1. Add as the very first line:
   ```js
   // Cerebro companion server — forked from the superpowers visual companion (MIT, see LICENSE-superpowers).
   ```
   (This is the one permitted "superpowers" mention in scripts — update `tests/no-upstream-strings.test.js` so `server.cjs` skips line 1: replace `const lines = fs.readFileSync(...).split('\n');` with
   `const lines = fs.readFileSync(path.join(SCRIPTS, f), 'utf-8').split('\n').map((l, i) => (f === 'server.cjs' && i === 0 ? '' : l));`.)
2. Delete these declarations from the Configuration section: `SUPERPOWERS_VERSION`, `SUPERPOWERS_BRAND_IMAGE_URL`, `TELEMETRY_DISABLE_ENV_VARS`, `SUPERPOWERS_TELEMETRY_DISABLED`.
3. Delete the functions `readSuperpowersVersion`, `isTruthyEnv`, `brandMarkup`. Replace `renderBranding` with:
   ```js
   function renderBranding(html) {
     return html.split('<!-- BRANDING -->').join('<div class="brand">Cerebro</div>');
   }
   ```
   (`escapeHtmlText` stays; it is used in Task 5.)
4. In `waitingPage()`: title `<title>Cerebro</title>`, heading `<h1>Cerebro</h1>`, paragraph `Waiting for Claude to push a screen...`. Delete the four `.brand*` CSS rules inside it and replace with `.brand { color: #666; font-size: 0.9rem; margin-bottom: 1.5rem; }`.
5. In `bootstrapPage()`: `<title>Opening Cerebro</title>`.
6. Comment on `SESSION_DIR`: default stays `'/tmp/cerebro'` (the sed already renamed the env var; change the literal `/tmp/brainstorm` → `/tmp/cerebro`).
7. Fix remaining comments: "The companion is reachable…" may stay; any comment containing the word brainstorm gets it replaced by "Cerebro".

- [ ] **Step 7: Strip branding from frame-template.html and helper.js**

`scripts/frame-template.html`:
- `<title>Cerebro</title>`
- Replace the CSS comment block (`BRAINSTORM COMPANION FRAME TEMPLATE …`) with `/* CEREBRO FRAME — layout, theme and component CSS. Content is injected at <!-- CONTENT -->. */`
- Delete the `.brand a`, `.brand-copy`, `.brand-logo` rules and the dark-mode `.brand-logo` rule. Keep `.brand` and add `font-weight: 600; letter-spacing: 0.04em;` to it.

`scripts/helper.js`:
- Tombstone copy: heading `Cerebro paused`, paragraph `The Cerebro server has stopped. Ask Claude to bring it back — this page reconnects automatically.`
- Any remaining comment with "brainstorm" → "Cerebro".

`scripts/start-server.sh` / `scripts/stop-server.sh`: header comments "Start the Cerebro server…", "Stop the Cerebro server…"; the `--open` help text becomes `Auto-open the browser on the first screen.`

- [ ] **Step 8: Run the tests to verify they pass**

```bash
cd ~/dotfiles/claude/skills/cerebro && node --test tests/
```

Expected: all pass (`# fail 0`).

- [ ] **Step 9: Commit**

```bash
cd ~/dotfiles && git add claude/skills/cerebro && git commit -m "Cerebro: rename the forked companion server and drop upstream branding"
```

---

### Task 3: Session directories under ~/.cerebro, --topic / --session-dir, inbox dir

**Files:**
- Modify: `scripts/start-server.sh`, `scripts/stop-server.sh`, `scripts/server.cjs` (`startServer()` mkdirs and `onListen()` info JSON)
- Create: `tests/start-stop.test.sh`

**Interfaces:**
- Produces: `start-server.sh --topic <slug> [--open] [--host h] [--url-host h] [--idle-timeout-minutes n] [--foreground|--background]` or `start-server.sh --session-dir <path> […]`. Prints one JSON line: `{"type":"server-started","port","host","url_host","url","session_dir","screen_dir","state_dir","inbox_dir","idle_timeout_ms"}`.
- Produces: default session dir `${CEREBRO_HOME:-$HOME/.cerebro}/sessions/<basename of $PWD>/<YYYY-MM-DD>-<topic>`; port/token memory files `${CEREBRO_HOME:-$HOME/.cerebro}/sessions/<basename of $PWD>/.last-port` and `.last-token`.
- Produces: `server.cjs` creates `inbox/` next to `content/` and `state/`; exports `INBOX_DIR = path.join(SESSION_DIR, 'inbox')` for Task 4.
- Consumes: env names from Task 2.

- [ ] **Step 1: Write the failing shell test**

Create `tests/start-stop.test.sh` (make executable):

```bash
#!/usr/bin/env bash
# Lifecycle test for start-server.sh / stop-server.sh.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../scripts"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cerebro-startstop-XXXXXX")"
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
```

- [ ] **Step 2: Run it to verify it fails**

```bash
chmod +x ~/dotfiles/claude/skills/cerebro/tests/start-stop.test.sh && ~/dotfiles/claude/skills/cerebro/tests/start-stop.test.sh
```

Expected: `{"error": "Unknown argument: --topic"}` and several `FAIL` lines; exit 1.

- [ ] **Step 3: Rewrite the argument and directory section of start-server.sh**

In `scripts/start-server.sh` replace everything from `# Parse arguments` through the line `mkdir -p "${SESSION_DIR}/content" "$STATE_DIR"` with:

```bash
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
```

Also update the usage comment at the top of the file:

```bash
# Usage: start-server.sh (--topic <kebab-slug> | --session-dir <path>) [--open] [--host <bind-host>] [--url-host <display-host>] [--idle-timeout-minutes <n>] [--foreground|--background]
#
# New session: --topic creates <CEREBRO_HOME or ~/.cerebro>/sessions/<basename $PWD>/<YYYY-MM-DD>-<topic>/{content,inbox,state}.
# Restart:     --session-dir <that path> reuses the same port and key so the open tab reconnects.
```

And in the error message near the end of the file replace `${PROJECT_DIR:+ --project-dir $PROJECT_DIR}` with ` --session-dir $SESSION_DIR`.

- [ ] **Step 4: stop-server.sh never deletes**

In `scripts/stop-server.sh` delete the block

```bash
  # Only delete ephemeral /tmp directories
  if [[ "$SESSION_DIR" == /tmp/* ]]; then
    rm -rf "$SESSION_DIR"
  fi
```

and change the header comment to `# Kills the server process. Session directories are always kept — screens, inbox and decisions.md are the record.`

- [ ] **Step 5: server.cjs creates inbox/ and reports it**

In `scripts/server.cjs`:
- After `const STATE_DIR = path.join(SESSION_DIR, 'state');` add `const INBOX_DIR = path.join(SESSION_DIR, 'inbox');`
- In `startServer()` after the two `mkdirSync` lines add `if (!fs.existsSync(INBOX_DIR)) fs.mkdirSync(INBOX_DIR, { recursive: true });`
- In `onListen()` change the `info` object to:
  ```js
  const info = JSON.stringify({
    type: 'server-started', port: Number(PORT), host: HOST,
    url_host: URL_HOST, url: companionUrl(),
    session_dir: SESSION_DIR, screen_dir: CONTENT_DIR, state_dir: STATE_DIR, inbox_dir: INBOX_DIR,
    idle_timeout_ms: IDLE_TIMEOUT_MS
  });
  ```

- [ ] **Step 6: Run the shell test and the node tests**

```bash
~/dotfiles/claude/skills/cerebro/tests/start-stop.test.sh && cd ~/dotfiles/claude/skills/cerebro && node --test tests/
```

Expected: all `ok`, exit 0; node tests still `# fail 0`.

- [ ] **Step 7: Commit**

```bash
cd ~/dotfiles && git add claude/skills/cerebro && git commit -m "Cerebro: store sessions under ~/.cerebro, add --topic/--session-dir and an inbox dir"
```

---

### Task 4: Serve /inbox/* images

**Files:**
- Modify: `scripts/server.cjs` (`isRegularFileInsideContentDir`, `getNewestScreen`, `handleRequest`, `MIME_TYPES`)
- Create: `tests/inbox.test.js`

**Interfaces:**
- Consumes: `INBOX_DIR` (Task 3).
- Produces: `GET /inbox/<basename>` → file from `inbox/` with its MIME type; `isRegularFileInside(dir, filePath)` replaces `isRegularFileInsideContentDir(filePath)`.

- [ ] **Step 1: Write the failing test**

Create `tests/inbox.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { startServer, waitForStarted, get, stop, TOKEN } = require('./helpers');

const PORT = 47002;
// Smallest valid PNG (1x1, transparent).
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64');

test('/inbox/* serves images from the session inbox and nothing else', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-inbox-'));
  fs.mkdirSync(path.join(dir, 'inbox'));
  fs.writeFileSync(path.join(dir, 'inbox', 'design-a.png'), PNG);
  fs.writeFileSync(path.join(dir, 'inbox', 'notes.webp'), PNG);
  const child = startServer(PORT, dir);
  try {
    await waitForStarted(child);

    const png = await get(PORT, TOKEN, '/inbox/design-a.png');
    assert.equal(png.status, 200);
    assert.equal(png.headers['content-type'], 'image/png');
    assert.ok(png.body.equals(PNG));

    const webp = await get(PORT, TOKEN, '/inbox/notes.webp');
    assert.equal(webp.headers['content-type'], 'image/webp');

    assert.equal((await get(PORT, TOKEN, '/inbox/missing.png')).status, 404);
    assert.equal((await get(PORT, TOKEN, '/inbox/')).status, 404);
    assert.equal((await get(PORT, TOKEN, '/inbox/..%2Fstate%2Fserver-info')).status, 404);
    assert.equal((await get(PORT, TOKEN, '/inbox/.hidden')).status, 404);
    assert.equal((await get(PORT, null, '/inbox/design-a.png')).status, 403);
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd ~/dotfiles/claude/skills/cerebro && node --test tests/inbox.test.js
```

Expected: FAIL — `/inbox/design-a.png` returns 404.

- [ ] **Step 3: Generalise the file guard and add the route**

In `scripts/server.cjs`:

1. Replace `isRegularFileInsideContentDir(filePath)` with

   ```js
   function isRegularFileInside(dir, filePath) {
     let stat, realDir, realFilePath;
     try {
       stat = fs.lstatSync(filePath);
       if (stat.isSymbolicLink()) return false;
       if (!stat.isFile()) return false;
       if (stat.nlink !== 1) return false;
       realDir = fs.realpathSync(dir);
       realFilePath = fs.realpathSync(filePath);
     } catch (e) {
       return false;
     }
     return realFilePath.startsWith(realDir + path.sep);
   }
   ```

   and update the call in `getNewestScreen()` to `isRegularFileInside(CONTENT_DIR, fp)`.

2. Add `'.webp': 'image/webp'` to `MIME_TYPES`.

3. Add a helper above `handleRequest`:

   ```js
   // Serve one regular file from `dir` by basename. Rejects empty/dot names and
   // anything that isn't a regular file inside `dir` (symlinks, traversal, dirs).
   function serveFileFrom(dir, rawName, res) {
     const fileName = path.basename(decodeURIComponent(rawName));
     const filePath = path.join(dir, fileName);
     if (!fileName || fileName.startsWith('.') || !isRegularFileInside(dir, filePath)) {
       res.writeHead(404, securityHeaders());
       res.end('Not found');
       return;
     }
     const ext = path.extname(filePath).toLowerCase();
     res.writeHead(200, securityHeaders({ 'Content-Type': MIME_TYPES[ext] || 'application/octet-stream' }));
     res.end(fs.readFileSync(filePath));
   }
   ```

4. In `handleRequest`, replace the whole `else if (req.method === 'GET' && pathname.startsWith('/files/')) { … }` branch with:

   ```js
   } else if (req.method === 'GET' && pathname.startsWith('/files/')) {
     serveFileFrom(CONTENT_DIR, pathname.slice('/files/'.length), res);
   } else if (req.method === 'GET' && pathname.startsWith('/inbox/')) {
     serveFileFrom(INBOX_DIR, pathname.slice('/inbox/'.length), res);
   ```

   Note `decodeURIComponent` can throw on malformed input; wrap the body of `serveFileFrom` in `try { … } catch (e) { res.writeHead(404, securityHeaders()); res.end('Not found'); }`.

- [ ] **Step 4: Run all tests**

```bash
cd ~/dotfiles/claude/skills/cerebro && node --test tests/ && tests/start-stop.test.sh
```

Expected: `# fail 0`, shell test exit 0.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles && git add claude/skills/cerebro && git commit -m "Cerebro: serve reference images from the session inbox at /inbox/*"
```

---

### Task 5: Decision tree sidebar from state/tree.json

**Files:**
- Modify: `scripts/server.cjs` (`wrapInFrame`, new `treeScriptTag`, second `fs.watch` in `startServer`)
- Modify: `scripts/frame-template.html` (two-pane layout with `<nav id="tree">`)
- Modify: `scripts/helper.js` (`renderTree`, `escapeHtml`, mount on load)
- Create: `tests/tree.test.js`, `tests/helper-render.test.js`

**Interfaces:**
- Consumes: `STATE_DIR`.
- Produces: `state/tree.json` schema (from DESIGN.md):
  ```json
  { "topic": "string", "nodes": [ { "id": "string", "title": "string", "state": "resolved|current|pending", "chosen": "string?", "rejected": [ { "option": "string", "why": "string" } ]?, "children": [node]? } ] }
  ```
- Produces: the served page contains `<script id="cerebro-tree" type="application/json">…</script>` (JSON or `null`) and `<nav id="tree">`; `helper.js` exports `renderTree(tree) → html string` and `escapeHtml(s)`.
- Produces: editing `state/tree.json` broadcasts `{type:'reload'}` (debounced 100 ms) without a new screen.

- [ ] **Step 1: Write the failing renderTree unit test**

Create `tests/helper-render.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// helper.js is browser code; evaluate it in a CommonJS sandbox with no `window`
// so only the exported pure functions run.
const src = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'helper.js'), 'utf-8');
const shim = { exports: {} };
new Function('module', src)(shim);
const { renderTree, escapeHtml } = shim.exports;

test('escapeHtml escapes the five characters', () => {
  assert.equal(escapeHtml(`<a href="x">&'</a>`), '&lt;a href=&quot;x&quot;&gt;&amp;&#39;&lt;/a&gt;');
});

test('renderTree renders topic, states, chosen option and nested children', () => {
  const html = renderTree({
    topic: 'Deviza storage',
    nodes: [
      { id: 'source', title: 'Rate source', state: 'resolved', chosen: 'MNB XML',
        children: [{ id: 'cadence', title: 'Fetch cadence', state: 'current' }] },
      { id: 'shape', title: 'Table <shape>', state: 'pending' },
    ],
  });
  assert.match(html, /<h3 class="tree-topic">Deviza storage<\/h3>/);
  assert.match(html, /<li class="node resolved"[^>]*>.*Rate source.*<span class="chosen">MNB XML<\/span>/s);
  assert.match(html, /<li class="node current"[^>]*>.*Fetch cadence/s);
  assert.match(html, /<li class="node pending"[^>]*>.*Table &lt;shape&gt;/s);
  assert.equal((html.match(/<ul/g) || []).length, 2, 'outer list plus one nested list');
});

test('renderTree tolerates null, garbage and unknown states', () => {
  assert.match(renderTree(null), /tree-empty/);
  assert.match(renderTree({ nodes: 'nope' }), /tree-empty/);
  assert.match(renderTree({ nodes: [{ title: 'x', state: 'weird' }] }), /node pending/);
});
```

- [ ] **Step 2: Write the failing server test**

Create `tests/tree.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { startServer, waitForStarted, get, stop, sleep, TOKEN } = require('./helpers');

const PORT = 47003;
const pageJson = (body) => {
  const m = body.match(/<script id="cerebro-tree" type="application\/json">([\s\S]*?)<\/script>/);
  assert.ok(m, 'tree script tag present');
  return JSON.parse(m[1]);
};

test('the frame embeds state/tree.json, tolerates a bad file, and reloads when it changes', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-tree-'));
  fs.mkdirSync(path.join(dir, 'content')); fs.mkdirSync(path.join(dir, 'state'));
  fs.writeFileSync(path.join(dir, 'content', 'q1.html'), '<h2>Q1</h2>');
  const child = startServer(PORT, dir);
  try {
    await waitForStarted(child);

    // no tree yet → null, page still 200 with the sidebar mount point
    let res = await get(PORT, TOKEN, '/');
    assert.equal(res.status, 200);
    assert.equal(pageJson(res.body.toString()), null);
    assert.match(res.body.toString(), /<nav id="tree"/);

    // valid tree → embedded verbatim, with "</" made safe
    const tree = { topic: 'T </script>', nodes: [{ id: 'a', title: 'A', state: 'current' }] };
    fs.writeFileSync(path.join(dir, 'state', 'tree.json'), JSON.stringify(tree));
    res = await get(PORT, TOKEN, '/');
    assert.deepEqual(pageJson(res.body.toString()), tree);
    assert.doesNotMatch(res.body.toString(), /T <\/script>/);

    // invalid JSON → null, no crash
    fs.writeFileSync(path.join(dir, 'state', 'tree.json'), '{not json');
    res = await get(PORT, TOKEN, '/');
    assert.equal(res.status, 200);
    assert.equal(pageJson(res.body.toString()), null);

    // changing tree.json pushes a reload to connected clients
    const ws = new WebSocket(`ws://127.0.0.1:${PORT}/?key=${TOKEN}`);
    const gotReload = new Promise((resolve) => ws.addEventListener('message', (m) => { if (JSON.parse(m.data).type === 'reload') resolve(true); }));
    await new Promise((r) => ws.addEventListener('open', r));
    fs.writeFileSync(path.join(dir, 'state', 'tree.json'), JSON.stringify(tree));
    assert.equal(await Promise.race([gotReload, sleep(2000).then(() => false)]), true);
    ws.close();
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
```

- [ ] **Step 3: Run both to verify they fail**

```bash
cd ~/dotfiles/claude/skills/cerebro && node --test tests/helper-render.test.js tests/tree.test.js
```

Expected: FAIL — `renderTree is not a function`; "tree script tag present" assertion fails.

- [ ] **Step 4: Server — inject the tree and watch it**

In `scripts/server.cjs`:

1. Add after `wrapInFrame`'s neighbours (Helper Functions section):

   ```js
   // The decision tree Claude maintains in state/tree.json, embedded into the
   // frame as JSON for helper.js to render. Missing or invalid → null, never an error.
   function readTree() {
     try {
       return JSON.parse(fs.readFileSync(path.join(STATE_DIR, 'tree.json'), 'utf-8'));
     } catch (e) {
       return null;
     }
   }

   function treeScriptTag() {
     // "</" would end the script element early; < keeps the JSON valid and inert.
     const json = JSON.stringify(readTree()).replace(/</g, '\\u003c');
     return '<script id="cerebro-tree" type="application/json">' + json + '</script>';
   }
   ```

2. Change `wrapInFrame` to:

   ```js
   function wrapInFrame(content) {
     return renderBranding(frameTemplate)
       .replace('<!-- TREE -->', treeScriptTag())
       .replace('<!-- CONTENT -->', content);
   }
   ```

3. In `startServer()`, directly after `watcher.on('error', …)`, add:

   ```js
   // tree.json changes without a new screen (Claude resolved a node) still
   // deserve a refresh so the sidebar stays truthful.
   const stateWatcher = fs.watch(STATE_DIR, (eventType, filename) => {
     if (filename !== 'tree.json') return;
     if (debounceTimers.has('state:tree.json')) clearTimeout(debounceTimers.get('state:tree.json'));
     debounceTimers.set('state:tree.json', setTimeout(() => {
       debounceTimers.delete('state:tree.json');
       touchActivity();
       console.log(JSON.stringify({ type: 'tree-updated' }));
       broadcast({ type: 'reload' });
     }, 100));
   });
   stateWatcher.on('error', (err) => console.error('fs.watch error:', err.message));
   ```

   and in `shutdown()` add `stateWatcher.close();` after `watcher.close();`.

- [ ] **Step 5: Frame — two-pane layout with the sidebar mount**

In `scripts/frame-template.html` replace the `<body>` contents with:

```html
  <div class="header">
    <!-- BRANDING -->
    <div class="status">Connecting…</div>
  </div>

  <div class="shell">
    <nav id="tree" aria-label="Decision tree"></nav>
    <div class="main">
      <div id="frame-content">
        <!-- CONTENT -->
      </div>
    </div>
  </div>
  <!-- TREE -->
```

Replace the `.main` and `#frame-content` rules with:

```css
    .shell { flex: 1; display: flex; min-height: 0; }
    #tree {
      width: 280px; flex-shrink: 0; overflow-y: auto;
      background: var(--bg-secondary); border-right: 1px solid var(--border);
      padding: 1.25rem 1rem; font-size: 0.85rem;
    }
    #tree .tree-topic { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--text-secondary); margin-bottom: 0.75rem; }
    #tree .tree-empty { color: var(--text-tertiary); font-style: italic; }
    #tree ul { list-style: none; margin: 0; padding: 0; }
    #tree ul ul { margin-left: 1.1rem; border-left: 1px solid var(--border); padding-left: 0.6rem; }
    #tree .node { display: block; padding: 0.3rem 0; }
    #tree .node > .icon { display: inline-block; width: 1.2rem; }
    #tree .node.resolved > .icon { color: var(--success); }
    #tree .node.current > .icon { color: var(--accent); }
    #tree .node.current > .title { font-weight: 600; color: var(--accent); }
    #tree .node.pending > .title { color: var(--text-secondary); }
    #tree .node > .chosen { display: block; margin-left: 1.2rem; color: var(--text-secondary); font-size: 0.78rem; }
    @media (max-width: 800px) { .shell { flex-direction: column; } #tree { width: auto; border-right: 0; border-bottom: 1px solid var(--border); } }
    .main { flex: 1; overflow-y: auto; min-width: 0; }
    #frame-content { padding: 2rem; min-height: 100%; }
```

- [ ] **Step 6: helper.js — renderTree and mount**

In `scripts/helper.js`:

1. Replace the export block at the top with:

   ```js
   // Pure: next backoff delay (doubles, capped). Exported for unit tests.
   function nextReconnectDelay(current, max) {
     return Math.min(current * 2, max);
   }

   function escapeHtml(value) {
     return String(value)
       .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
       .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
   }

   // Pure: decision tree (state/tree.json) → sidebar HTML. Unknown states render as pending.
   var TREE_ICONS = { resolved: '✓', current: '▶', pending: '○' };
   function renderTree(tree) {
     if (!tree || !Array.isArray(tree.nodes)) return '<p class="tree-empty">No decisions yet</p>';
     var renderNode = function (n) {
       var state = TREE_ICONS[n && n.state] ? n.state : 'pending';
       var html = '<li class="node ' + state + '" data-id="' + escapeHtml(n.id || '') + '">' +
         '<span class="icon">' + TREE_ICONS[state] + '</span>' +
         '<span class="title">' + escapeHtml(n.title || '') + '</span>';
       if (n.chosen) html += '<span class="chosen">' + escapeHtml(n.chosen) + '</span>';
       if (Array.isArray(n.children) && n.children.length) html += '<ul>' + n.children.map(renderNode).join('') + '</ul>';
       return html + '</li>';
     };
     return (tree.topic ? '<h3 class="tree-topic">' + escapeHtml(tree.topic) + '</h3>' : '') +
       '<ul class="tree">' + tree.nodes.map(renderNode).join('') + '</ul>';
   }

   if (typeof module !== 'undefined' && module.exports) {
     module.exports = { nextReconnectDelay, renderTree, escapeHtml, MIN_RECONNECT_MS, MAX_RECONNECT_MS, TOMBSTONE_AFTER_MS };
   }
   ```

2. Just before the final `connect();` add:

   ```js
   // Render the decision tree the server embedded (absent on full-document screens).
   (function mountTree() {
     var data = document.getElementById('cerebro-tree');
     var target = document.getElementById('tree');
     if (!data || !target) return;
     var tree = null;
     try { tree = JSON.parse(data.textContent); } catch (e) {}
     target.innerHTML = renderTree(tree);
   })();
   ```

- [ ] **Step 7: Run all tests**

```bash
cd ~/dotfiles/claude/skills/cerebro && node --test tests/ && tests/start-stop.test.sh
```

Expected: `# fail 0`, shell exit 0.

- [ ] **Step 8: Commit**

```bash
cd ~/dotfiles && git add claude/skills/cerebro && git commit -m "Cerebro: persistent decision-tree sidebar rendered from state/tree.json"
```

---

### Task 6: Frame components, note channel, recommended badge, mermaid, theme

**Files:**
- Modify: `scripts/frame-template.html` (CSS for `.gallery`, `.compare`, tables, badge, note form, TokyoNight dark palette, mermaid loader)
- Modify: `scripts/helper.js` (note form submit; `toggleSelect` handles `.gallery figure`)
- Modify: `scripts/server.cjs` (`handleMessage` persists notes)
- Create: `tests/events.test.js`, `tests/frame.test.js`

**Interfaces:**
- Produces (events JSONL in `state/events`): `{"type":"click","choice":"a","text":"…","id":null,"timestamp":…}` and `{"type":"note","text":"…","timestamp":…}`.
- Produces (markup contract, documented in Task 8): `.options > .option[data-choice][data-recommended?]`, `.options[data-multiselect]`, `.gallery > figure[data-choice] > img + figcaption`, `.compare > .pane > .pane-title + pre`, `.pros-cons`, `table`, `<pre class="mermaid">`, and the frame-provided `#note-form`.

- [ ] **Step 1: Write the failing events test**

Create `tests/events.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { startServer, waitForStarted, stop, sleep, TOKEN } = require('./helpers');

const PORT = 47004;

test('clicks and notes land in state/events; other messages do not', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-events-'));
  const child = startServer(PORT, dir);
  try {
    await waitForStarted(child);
    const ws = new WebSocket(`ws://127.0.0.1:${PORT}/?key=${TOKEN}`);
    await new Promise((r) => ws.addEventListener('open', r));
    ws.send(JSON.stringify({ type: 'click', choice: 'b', text: 'B Two column', id: null, timestamp: 1 }));
    ws.send(JSON.stringify({ type: 'note', text: 'B but without the enum', timestamp: 2 }));
    ws.send(JSON.stringify({ type: 'ping', timestamp: 3 }));
    ws.send(JSON.stringify({ type: 'note', text: '   ', timestamp: 4 }));
    await sleep(300);
    ws.close();

    const lines = fs.readFileSync(path.join(dir, 'state', 'events'), 'utf-8').trim().split('\n').map(JSON.parse);
    assert.deepEqual(lines.map((e) => e.type), ['click', 'note']);
    assert.equal(lines[1].text, 'B but without the enum');
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
```

- [ ] **Step 2: Write the failing frame test**

Create `tests/frame.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const frame = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'frame-template.html'), 'utf-8');
const helper = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'helper.js'), 'utf-8');

test('frame provides the component CSS the visual guide documents', () => {
  for (const sel of ['.gallery', '.compare', '.pane-title', '.option[data-recommended]', '.pros-cons', '.note-status', 'table']) {
    assert.ok(frame.includes(sel), `missing CSS for ${sel}`);
  }
});

test('frame has the note form, the tree mount, both placeholders and the mermaid loader', () => {
  assert.match(frame, /<form id="note-form"/);
  assert.match(frame, /<textarea id="note-text"/);
  assert.match(frame, /<nav id="tree"/);
  assert.ok(frame.includes('<!-- CONTENT -->') && frame.includes('<!-- TREE -->') && frame.includes('<!-- BRANDING -->'));
  assert.match(frame, /cdn\.jsdelivr\.net\/npm\/mermaid@11/);
});

test('helper wires the note form and gallery selection', () => {
  assert.match(helper, /note-form/);
  assert.match(helper, /type: 'note'/);
  assert.match(helper, /\.gallery/);
});
```

- [ ] **Step 3: Run both to verify they fail**

```bash
cd ~/dotfiles/claude/skills/cerebro && node --test tests/events.test.js tests/frame.test.js
```

Expected: FAIL — events has only the click line; frame assertions fail on `.gallery`, `#note-form`, mermaid.

- [ ] **Step 4: server.cjs — persist notes**

In `handleMessage`, replace

```js
  if (event && event.choice) {
```

with

```js
  const isClick = event && event.type === 'click' && event.choice;
  const isNote = event && event.type === 'note' && typeof event.text === 'string' && event.text.trim();
  if (isClick || isNote) {
```

(The upstream `window.brainstorm.choice()` API sent `{type:'choice', value}`; Cerebro screens use `data-choice` clicks only, so `type === 'click'` is the contract.)

- [ ] **Step 5: frame-template.html — components, note form, palette, mermaid**

Add the note form inside `.main`, after `#frame-content`'s closing `</div>` and still inside `.main`:

```html
      <form id="note-form" class="note" autocomplete="off">
        <textarea id="note-text" rows="2" placeholder="Note for Claude — sent with your clicks. The terminal is still where you answer."></textarea>
        <div class="note-row">
          <span class="note-status" aria-live="polite"></span>
          <button type="submit">Send note</button>
        </div>
      </form>
```

Add before `</head>`:

```html
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
    const dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    mermaid.initialize({ startOnLoad: true, theme: dark ? 'dark' : 'default', securityLevel: 'strict' });
  </script>
```

(If the CDN is unreachable the module fails to load and `<pre class="mermaid">` blocks stay as readable source text — the degradation DESIGN.md accepts.)

Replace the dark `:root` palette block with TokyoNight Moon (matches the user's Ghostty/Claude theme):

```css
    @media (prefers-color-scheme: dark) {
      :root {
        --bg-primary: #222436;
        --bg-secondary: #1e2030;
        --bg-tertiary: #2f334d;
        --border: #3b4261;
        --text-primary: #c8d3f5;
        --text-secondary: #828bb8;
        --text-tertiary: #636da6;
        --accent: #82aaff;
        --accent-hover: #89ddff;
        --success: #c3e88d;
        --warning: #ffc777;
        --error: #ff757f;
        --selected-bg: rgba(130, 170, 255, 0.14);
        --selected-border: #82aaff;
      }
    }
```

Append these component rules to the `<style>` block (after `.mock-input`):

```css
    /* ===== RECOMMENDED BADGE ===== */
    .option[data-recommended] { border-style: dashed; }
    .option[data-recommended] .content h3::after,
    .gallery figure[data-recommended] figcaption::after {
      content: 'recommended'; margin-left: 0.5rem; font-size: 0.65rem; font-weight: 600;
      text-transform: uppercase; letter-spacing: 0.05em; color: var(--accent);
      border: 1px solid var(--accent); border-radius: 999px; padding: 0.05rem 0.45rem; vertical-align: middle;
    }

    /* ===== GALLERY (labelled reference images) ===== */
    .gallery { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }
    .gallery figure {
      margin: 0; background: var(--bg-secondary); border: 2px solid var(--border); border-radius: 12px;
      overflow: hidden; cursor: pointer; transition: border-color 0.15s ease;
    }
    .gallery figure:hover { border-color: var(--accent); }
    .gallery figure.selected { border-color: var(--selected-border); background: var(--selected-bg); }
    .gallery img { display: block; width: 100%; height: auto; background: var(--bg-tertiary); }
    .gallery figcaption { padding: 0.6rem 0.9rem; font-size: 0.85rem; font-weight: 600; }
    .gallery figcaption small { display: block; font-weight: 400; color: var(--text-secondary); }

    /* ===== COMPARE (code shapes side by side) ===== */
    .compare { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }
    .pane { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; min-width: 0; }
    .pane-title { background: var(--bg-tertiary); padding: 0.5rem 1rem; font-size: 0.75rem; color: var(--text-secondary); border-bottom: 1px solid var(--border); }
    .pane pre, pre.code {
      margin: 0; padding: 1rem; overflow-x: auto; font-size: 0.8rem; line-height: 1.45;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace; color: var(--text-primary); tab-size: 2;
    }
    .pane mark { background: var(--selected-bg); color: inherit; outline: 1px solid var(--selected-border); border-radius: 3px; }

    /* ===== TABLES ===== */
    table { width: 100%; border-collapse: collapse; font-size: 0.85rem; margin-bottom: 1.5rem; background: var(--bg-secondary); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
    th, td { text-align: left; padding: 0.55rem 0.9rem; border-bottom: 1px solid var(--border); vertical-align: top; }
    th { background: var(--bg-tertiary); font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-secondary); }
    tr:last-child td { border-bottom: 0; }
    td code, p code, li code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.85em; background: var(--bg-tertiary); padding: 0.05rem 0.35rem; border-radius: 4px; }

    /* ===== MERMAID ===== */
    pre.mermaid { background: var(--bg-secondary); border: 1px solid var(--border); border-radius: 12px; padding: 1rem; margin-bottom: 1.5rem; overflow-x: auto; }

    /* ===== NOTE FORM (frame-provided) ===== */
    .note { position: sticky; bottom: 0; background: var(--bg-secondary); border-top: 1px solid var(--border); padding: 0.75rem 2rem; }
    .note textarea {
      width: 100%; resize: vertical; background: var(--bg-primary); color: var(--text-primary);
      border: 1px solid var(--border); border-radius: 8px; padding: 0.5rem 0.75rem; font: inherit; font-size: 0.85rem;
    }
    .note-row { display: flex; align-items: center; justify-content: flex-end; gap: 1rem; margin-top: 0.4rem; }
    .note-status { font-size: 0.75rem; color: var(--text-secondary); }
    .note button { background: var(--accent); color: white; border: 0; border-radius: 6px; padding: 0.4rem 0.9rem; font-size: 0.8rem; cursor: pointer; }
    .note button:hover { background: var(--accent-hover); }
```

Make `.main` a column flex so the note form sits under the scrolling content: change `.main { flex: 1; overflow-y: auto; min-width: 0; }` to `.main { flex: 1; min-width: 0; display: flex; flex-direction: column; overflow: hidden; }` and `#frame-content { padding: 2rem; min-height: 100%; }` to `#frame-content { padding: 2rem; flex: 1; overflow-y: auto; }`.

- [ ] **Step 6: helper.js — note submit and gallery selection**

In `scripts/helper.js`:

1. Replace `window.toggleSelect` with:

   ```js
   window.toggleSelect = function(el) {
     const container = el.closest('.options') || el.closest('.cards') || el.closest('.gallery');
     const multi = container && container.dataset.multiselect !== undefined;
     if (container && !multi) {
       container.querySelectorAll('.option, .card, figure').forEach(o => o.classList.remove('selected'));
     }
     if (multi) {
       el.classList.toggle('selected');
     } else {
       el.classList.add('selected');
     }
     window.selectedChoice = el.dataset.choice;
   };
   ```

2. Before `connect();` (after `mountTree`) add:

   ```js
   // Frame-provided note box: free text for Claude, recorded next to the clicks.
   (function mountNoteForm() {
     const form = document.getElementById('note-form');
     const text = document.getElementById('note-text');
     const status = form && form.querySelector('.note-status');
     if (!form || !text) return;
     form.addEventListener('submit', (e) => {
       e.preventDefault();
       const value = text.value.trim();
       if (!value) return;
       sendEvent({ type: 'note', text: value });
       text.value = '';
       if (status) { status.textContent = 'Sent ✓ — answer in the terminal to continue'; setTimeout(() => { status.textContent = ''; }, 4000); }
     });
     text.addEventListener('keydown', (e) => {
       if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') form.requestSubmit();
     });
   })();
   ```

3. Replace the `window.cerebro = {…}` block with `window.cerebro = { send: sendEvent };` (the `choice()` helper is gone with the `type:'choice'` contract).

- [ ] **Step 7: Run all tests**

```bash
cd ~/dotfiles/claude/skills/cerebro && node --test tests/ && tests/start-stop.test.sh
```

Expected: `# fail 0`, shell exit 0.

- [ ] **Step 8: Commit**

```bash
cd ~/dotfiles && git add claude/skills/cerebro && git commit -m "Cerebro: gallery/compare/table components, recommended badge, note channel, TokyoNight palette"
```

---

### Task 7: Demo session and in-browser verification

**Files:**
- Create: `demo/tree.json`, `demo/demo.html`, `demo/pixel.png`, `demo/run-demo.sh`

**Interfaces:**
- Consumes: everything from Tasks 3–6.
- Produces: `demo/run-demo.sh` — starts a session with `--topic demo --open`, copies the image into `inbox/`, the tree into `state/`, the screen into `content/`, prints the URL. Used for the manual checks in DESIGN.md "Verification" 1–4.

- [ ] **Step 1: Create the demo tree**

`demo/tree.json`:

```json
{
  "topic": "Demo: deviza rate storage",
  "nodes": [
    { "id": "source", "title": "Rate source", "state": "resolved", "chosen": "MNB XML feed",
      "rejected": [{ "option": "ECB reference rates", "why": "no HUF base, one day behind" }],
      "children": [
        { "id": "cadence", "title": "Fetch cadence", "state": "resolved", "chosen": "Daily 14:30 + manual replay" }
      ] },
    { "id": "shape", "title": "Table shape", "state": "current" },
    { "id": "api", "title": "Read endpoint", "state": "pending" },
    { "id": "events", "title": "Domain events", "state": "pending" }
  ]
}
```

- [ ] **Step 2: Create the demo screen (every component once)**

`demo/demo.html`:

```html
<h2>Which table shape for daily rates?</h2>
<p class="subtitle">One row per (date, currency) vs one row per date with a JSON column. Recommended: A — it keeps Prisma queries and the outlier job trivial.</p>

<div class="options">
  <div class="option" data-choice="a" data-recommended onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content"><h3>Row per (date, currency)</h3><p>Composite unique key, indexable, plain SQL for outliers.</p></div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">
    <div class="letter">B</div>
    <div class="content"><h3>Row per date, rates as JSON</h3><p>One fetch = one insert; every read unpacks JSON.</p></div>
  </div>
</div>

<div class="section">
  <div class="label">Shapes side by side</div>
  <div class="compare">
    <div class="pane"><div class="pane-title">A — schema.prisma</div><pre>model DailyRate {
  date      DateTime @db.Date
  currency  String   @db.VarChar(3)
  rate      Decimal  @db.Decimal(18, 6)
  <mark>@@id([date, currency])</mark>
}</pre></div>
    <div class="pane"><div class="pane-title">B — schema.prisma</div><pre>model DailyRates {
  date   DateTime @id @db.Date
  rates  Json
}</pre></div>
    <div class="pane"><div class="pane-title">Response DTO (both)</div><pre>export interface IGetDailyRatesResponseBody {
  date: string;
  rates: { currency: string; rate: string }[];
}</pre></div>
  </div>
</div>

<div class="section">
  <div class="label">Reference screenshots</div>
  <div class="gallery">
    <figure data-choice="design-a" data-recommended onclick="toggleSelect(this)"><img src="/inbox/pixel.png" alt="Design A"><figcaption>Design A <small>card grid, from Figma</small></figcaption></figure>
    <figure data-choice="design-b" onclick="toggleSelect(this)"><img src="/inbox/pixel.png" alt="Design B"><figcaption>Design B <small>single table</small></figcaption></figure>
  </div>
</div>

<div class="section">
  <div class="label">Endpoints touched</div>
  <table>
    <thead><tr><th>Method</th><th>Path</th><th>Handler</th></tr></thead>
    <tbody>
      <tr><td>GET</td><td><code>/currency/rates?date=</code></td><td><code>GetDailyRatesQuery</code></td></tr>
      <tr><td>POST</td><td><code>/currency/rates/replay</code></td><td><code>ReplayRatesCommand</code></td></tr>
    </tbody>
  </table>
</div>

<div class="section">
  <div class="label">Flow</div>
  <pre class="mermaid">sequenceDiagram
  participant Job as FetchRatesJob
  participant MNB
  participant DB
  Job->>MNB: GET arfolyamok.xml
  MNB-->>Job: rates
  Job->>DB: upsert DailyRate[]
  Job-->>Kafka: RatesFetchedEvent</pre>
</div>

<div class="pros-cons">
  <div class="pros"><h4>Pros of A</h4><ul><li>Indexed lookups</li><li>Outlier SQL is one query</li></ul></div>
  <div class="cons"><h4>Cons of A</h4><ul><li>~30 rows/day instead of 1</li></ul></div>
</div>
```

- [ ] **Step 3: Create the image and the runner**

```bash
cd ~/dotfiles/claude/skills/cerebro/demo
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -d > pixel.png
file pixel.png
```

Expected: `pixel.png: PNG image data, 1 x 1`.

`demo/run-demo.sh` (make executable):

```bash
#!/usr/bin/env bash
# Start a Cerebro demo session and push one screen that uses every component.
# Usage: demo/run-demo.sh   (then open the printed URL; Ctrl-click in Ghostty)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
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
```

- [ ] **Step 4: Run the demo and check the four spec verifications**

```bash
chmod +x ~/dotfiles/claude/skills/cerebro/demo/run-demo.sh && ~/dotfiles/claude/skills/cerebro/demo/run-demo.sh
```

Expected: the browser opens on the demo screen. Check, and fix in the relevant script if anything is off:

1. Sidebar shows the topic, two ✓ nodes (one nested with its chosen text), one ▶, two ○. Right pane shows options with the *recommended* pill on A, three compare panes with the `@@id` line highlighted, two gallery figures, the endpoint table, a rendered sequence diagram, pros/cons, and the note box at the bottom.
2. Click option B, then type a note and press ⌘↵. Then: `cat <session>/state/events` → one `click` line (`"choice":"b"`) and one `note` line.
3. Edit `<session>/state/tree.json` — set `"shape"` to `"state":"resolved","chosen":"A"` — the sidebar updates within a second without a new screen. Copy `demo.html` to a new filename in `content/`; confirm `events` is now gone (cleared on new screen).
4. `scripts/stop-server.sh <session>` — tab shows the "Cerebro paused" overlay after ~15 s. `scripts/start-server.sh --session-dir <session>` — tab reconnects on the same port with no new URL needed.

Record anything you had to fix as part of this task's commit. Stop the server when done.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles && git add claude/skills/cerebro && git commit -m "Cerebro: demo session exercising every frame component"
```

---

### Task 8: SKILL.md and visual-guide.md

**Files:**
- Create: `SKILL.md`, `visual-guide.md`

**Interfaces:**
- Consumes: the CLI (Task 3), the markup contract and events (Task 6), tree.json (Task 5).
- Produces: the skill Claude Code loads from `~/.claude/skills/cerebro/SKILL.md`.

- [ ] **Step 1: Write SKILL.md**

Create `SKILL.md` with exactly this content:

````markdown
---
name: cerebro
description: Interrogate a decision grilling-style while a local browser tab shows what the questions are about — reference images, DTO/zod/Prisma shapes side by side, endpoint tables, event chains, diagrams, and the live decision tree. Use when the user says `cerebro` or `cerebro <topic>`. Also invoke it — at most once per conversation — when a question you are about to ask would be clearer shown than told, to make the one-time offer.
---

# Cerebro

Grilling with a screen. You walk the user's decision tree one question at a time; when a
question has a *shape* — an image, two DTOs, a schema, a flow — you put that shape in a
browser tab first. It ends in a decision record, never in implementation.

## Two ways in

**Trigger.** The user typed `cerebro` or `cerebro <topic>`. Start a session (below).

**Offer.** You were about to ask something that would be clearer seen than read. Send
this, alone, as its own message, and end your turn:

> This next part might be easier if I show you — I can put the options, shapes and
> images in a browser tab as we go (Cerebro). Want me to open it?

No question, summary or other content in that message. If the answer is no, continue in
the terminal and **do not offer again in this conversation**. If yes, start a session.
One offer per conversation, ever.

## Stance

1. Walk every branch of the decision tree, resolving dependencies one by one.
2. **One question per message.** Wait for the answer. Several at once is bewildering.
3. **Every question carries your recommended answer** and the reason for it.
4. **Facts are yours to look up** — files, git, tools, docs. Never ask the user something
   `grep` can answer. **Decisions are theirs** — put each one to them and wait.
5. **Act on nothing** until the user confirms shared understanding.

## Session start

1. Choose a kebab-case topic slug from the request (`deviza-storage`).
2. Start the server from the project directory:
   ```bash
   "$HOME/.claude/skills/cerebro/scripts/start-server.sh" --topic <slug> --open
   ```
   Keep `session_dir`, `screen_dir`, `state_dir`, `inbox_dir` and `url` from the JSON line
   it prints. The URL carries the session key — always give the user the **complete** URL.
3. Write the first `state/tree.json` (see visual-guide.md): every decision you can already
   see as `pending`, the first as `current`.
4. Tell the user, in one short message: the URL; that the tab opens on the first screen;
   and that **images you should show must be files** — drop them into `inbox_dir`, or drag
   a file into the terminal and you will copy it there. A pasted image cannot be re-shown.
5. Ask the first question.

## The loop

For each question:

1. **Look up the facts** the question depends on before asking it.
2. **Decide the surface.** Ask in the terminal always. *Also* push a screen when the
   content has a shape:
   - referenced images — `gallery`, labelled, so "Design B" has a name
   - two or more code shapes — `compare`: DTO ↔ zod ↔ Prisma, old ↔ new interface
   - structures — endpoint or field `table`, module or event `mermaid`, state machines
   - UI layout comparisons
   Keep to the terminal when the answer is words: scope, naming, wording, yes/no with
   nothing to look at. A technical *topic* does not force the browser; a technical
   *shape* earns it.
3. **If pushing a screen:** check the server is alive (`state/server-info` exists,
   `state/server-stopped` does not — else restart with
   `start-server.sh --session-dir <session_dir>`, same port, tab reconnects). Write a
   content fragment to `screen_dir/<semantic-name>.html` with the Write tool (never a
   heredoc — it floods the terminal). **Fresh filename every time** (`table-shape.html`,
   `table-shape-v2.html`); the newest file is what the tab shows. Mark your recommended
   option with `data-recommended`.
4. **Ask in the terminal** — the question, the options in a line each, your recommendation
   and why, and "(also on screen)" when you pushed one. End your turn.
5. **Next turn:** if `state/events` exists, read it — clicks (`type: click`, `choice`) and
   notes (`type: note`, `text`). The terminal reply is primary; events fill in what they
   clicked and typed. Update `state/tree.json`: the answered node → `resolved` with
   `chosen` and `rejected[]`, the next node → `current`, new nodes the answer revealed →
   `pending` (nested under their parent when they exist only because of it). The sidebar
   refreshes by itself.
6. **Iterate or advance.** If the answer changes the current screen, push a `-v2`. When the
   next question is terminal-only, push `waiting-N.html`:
   ```html
   <div style="display:flex;align-items:center;justify-content:center;min-height:40vh">
     <p class="subtitle">Continuing in the terminal…</p>
   </div>
   ```
   so the tab never shows a resolved choice as if it were open.

## Ending

When every node is resolved and the user confirms shared understanding:

1. Write `<session_dir>/decisions.md` from `tree.json` (template in visual-guide.md).
2. Stop the server: `"$HOME/.claude/skills/cerebro/scripts/stop-server.sh" <session_dir>`.
3. Print the path of `decisions.md` and a three-line summary. **Stop.** Do not invoke
   `writing-plans` or any implementation skill — building is the user's next request.

## Reference

Markup for every component, the events format, the `tree.json` schema and the
`decisions.md` template: read `visual-guide.md` in this directory before pushing your
first screen.
````

- [ ] **Step 2: Write visual-guide.md**

Create `visual-guide.md` with exactly this content:

````markdown
# Cerebro visual guide

Reference for the browser side of a Cerebro session. Read once per session before the
first screen.

## Server

```bash
S="$HOME/.claude/skills/cerebro/scripts"
"$S/start-server.sh" --topic <kebab-slug> --open      # new session; prints one JSON line
"$S/start-server.sh" --session-dir <session_dir>      # restart: same port + key, tab reconnects
"$S/stop-server.sh"  <session_dir>                    # stop; the directory is kept
```

Startup JSON: `port, url, session_dir, screen_dir, state_dir, inbox_dir, idle_timeout_ms`.
The URL contains `?key=` — hand it over complete. If you lost the JSON, read
`<state_dir>/server-info`. The server exits after 4 h idle or when the Claude Code process
that started it dies; `<state_dir>/server-stopped` marks that.

Session layout:

```text
<session_dir>/
  content/     screens; newest .html by mtime is served, wrapped in the frame
  inbox/       user images, served at /inbox/<name>; also reachable: content/ at /files/<name>
  state/       server-info · server-stopped · tree.json (yours) · events (theirs)
  decisions.md written by you at the end
```

## Screens

Write **fragments** — the server wraps them in the frame (header, sidebar, CSS, note box,
helper script). Start with `<!DOCTYPE` or `<html` only if you need the whole page. Use the
Write tool, never a heredoc. Fresh filename per screen; suffix `-v2`, `-v3` for iterations.
Every screen opens with the question and the recommendation:

```html
<h2>Which table shape for daily rates?</h2>
<p class="subtitle">Recommended: A — plain SQL for the outlier job.</p>
```

HTML-escape `<`, `>` and `&` inside `<pre>` (`&lt;`, `&gt;`, `&amp;`).

### options — A/B/C

```html
<div class="options">                       <!-- add data-multiselect for several -->
  <div class="option" data-choice="a" data-recommended onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content"><h3>Title</h3><p>One-line consequence.</p></div>
  </div>
  <div class="option" data-choice="b" onclick="toggleSelect(this)">…</div>
</div>
```

### gallery — labelled reference images

```html
<div class="gallery">
  <figure data-choice="design-a" onclick="toggleSelect(this)">
    <img src="/inbox/design-a.png" alt="Design A">
    <figcaption>Design A <small>card grid, Figma export</small></figcaption>
  </figure>
</div>
```

Files must already be in `inbox/`. Name them so the caption and the filename agree.

### compare — code shapes side by side

```html
<div class="compare">
  <div class="pane"><div class="pane-title">DTO — class-validator</div><pre>export class CreateRateRequestBody {
  @IsISO4217CurrencyCode() currency!: string;
}</pre></div>
  <div class="pane"><div class="pane-title">zod</div><pre>z.object({ currency: z.string().length(3) })</pre></div>
  <div class="pane"><div class="pane-title">Prisma</div><pre>model Rate { <mark>currency String @db.VarChar(3)</mark> }</pre></div>
</div>
```

`<mark>` highlights the line the question is about. Two to four panes.

### table, pros-cons, mermaid

```html
<table><thead><tr><th>Method</th><th>Path</th><th>Handler</th></tr></thead>
<tbody><tr><td>GET</td><td><code>/rates</code></td><td><code>GetRatesQuery</code></td></tr></tbody></table>

<div class="pros-cons">
  <div class="pros"><h4>Pros</h4><ul><li>…</li></ul></div>
  <div class="cons"><h4>Cons</h4><ul><li>…</li></ul></div>
</div>

<pre class="mermaid">flowchart LR
  Job --> MNB --> DB --> Kafka</pre>
```

Mermaid loads from a CDN; offline the block shows its source text.

### Typography

`h2` question · `h3` section · `.subtitle` · `.label` (small caps) · `.section` (spacing) ·
`.split` (two columns) · `.mockup`/`.mockup-header`/`.mockup-body` and `.mock-*` for
wireframes.

## Feedback: state/events

JSON lines; cleared whenever a new screen file appears. Read it on the turn after you
asked. The terminal reply is primary; this fills in what they clicked and typed.

```jsonl
{"type":"click","choice":"a","text":"A Row per (date, currency) …","id":null,"timestamp":1756200101000}
{"type":"note","text":"B but without the enum","timestamp":1756200115000}
```

Several clicks show the exploration path; the last click is usually the pick. A click that
disagrees with the terminal reply is worth one clarifying sentence.

## The tree: state/tree.json

You own this file. Rewrite it after every answer; the sidebar reloads by itself.

```json
{
  "topic": "Deviza rate storage",
  "nodes": [
    { "id": "source", "title": "Rate source", "state": "resolved",
      "chosen": "MNB XML feed",
      "rejected": [{ "option": "ECB reference rates", "why": "no HUF base" }],
      "children": [
        { "id": "cadence", "title": "Fetch cadence", "state": "current" }
      ] },
    { "id": "shape", "title": "Table shape", "state": "pending" }
  ]
}
```

- `state`: `resolved` (✓, shows `chosen`) · `current` (▶, exactly one) · `pending` (○).
- `children`: decisions that exist only because of the parent's answer.
- Add nodes as answers reveal them; never delete one — mark it `resolved` with
  `"chosen": "n/a — <why it vanished>"` so the record stays honest.

## The record: decisions.md

Written from `tree.json` at the end, to `<session_dir>/decisions.md`:

```markdown
# <topic> — decisions

*<YYYY-MM-DD>, Cerebro session in <project-slug>*

## 1. <node title>
**Chosen:** <chosen>
**Rejected:** <option> — <why>; <option> — <why>

### 1.1 <child title>
**Chosen:** …

## Open follow-ups
- <anything the user deferred, or "none">
```

Number top-level nodes in order; children as `n.m`. Copy `rejected[].why` verbatim — it is
the part people forget.
````

- [ ] **Step 3: Verify frontmatter and forbidden strings**

```bash
cd ~/dotfiles/claude/skills/cerebro
head -4 SKILL.md | grep -E '^(name: cerebro|description: )' | wc -l   # expect 2
grep -n -i 'brainstorm\|superpowers' SKILL.md visual-guide.md ; echo "exit=$? (1 = clean)"
node --test tests/ && tests/start-stop.test.sh
```

Expected: `2`; `exit=1 (1 = clean)`; tests pass.

- [ ] **Step 4: Check the skill is visible to Claude Code**

Start a new Claude Code session in any directory and confirm `cerebro` appears in the
available-skills list (the `Skill` tool listing shows `cerebro: Interrogate a decision…`).
If not: `ls -la ~/.claude/skills/cerebro/SKILL.md` must resolve through the symlink.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles && git add claude/skills/cerebro && git commit -m "Cerebro: SKILL.md and visual guide"
```

---

### Task 9: Dogfood on a real decision and tune

**Files:**
- Modify (as needed): `SKILL.md`, `visual-guide.md`, `scripts/*`

**Interfaces:** none new.

- [ ] **Step 1: Run one real session**

In `~/work/bupa/bupa-monorepo`, in a fresh Claude Code session, type `cerebro deviza-backend`
(or any live decision). Go through at least four questions, at least two with screens, one
with a dragged-in image, one terminal-only (expect a `waiting-N.html`). Finish to
`decisions.md`.

- [ ] **Step 2: Note what chafed**

Write down, in the terminal, each friction point with the file that owns it (skill text,
guide, CSS, server). Typical candidates: the offer text, the sidebar width, `compare` pane
minimum width, whether the terminal message repeats too much of the screen.

- [ ] **Step 3: Fix, re-run the tests, commit**

```bash
cd ~/dotfiles/claude/skills/cerebro && node --test tests/ && tests/start-stop.test.sh
cd ~/dotfiles && git add claude/skills/cerebro && git commit -m "Cerebro: tune after first real session"
```

- [ ] **Step 4: Delete this plan**

The plan has served; DESIGN.md stays as the durable description.

```bash
cd ~/dotfiles && git rm claude/skills/cerebro/PLAN.md && git commit -m "Cerebro: remove the implementation plan, DESIGN.md is the record"
```
