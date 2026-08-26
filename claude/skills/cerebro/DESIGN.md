# Cerebro — design

*Written 2026-08-26. A personal Claude Code skill; lives in the dotfiles repo, never in a work repo.*

## What it is

A decision-interrogation skill with a browser tab. It takes the stance of `grilling`
(walk the decision tree, one question per turn, always recommend an answer, look up
facts, ask only decisions, act on nothing until shared understanding) and adds a local
web page that *shows* what the question is about — referenced images, DTOs side by
side, Prisma models, endpoint tables, event chains, mermaid diagrams — with a
persistent view of the decision tree. It ends by writing a decision record.

It is not a design pipeline: no approaches-and-spec ceremony, no hand-off to an
implementation skill. Implementation is a new request.

## Why not the existing pieces

- `grilling` has the right stance and no visuals.
- `superpowers:brainstorming` has a "Visual Companion" with the right mechanism (local
  Node server, HTML fragments, clicks recorded to a file) but the opposite policy — it
  routes "API design, data modeling, technical decisions" to the terminal, which is
  exactly the content this skill exists to show — and it lives at a plugin-cache path
  that changes on every plugin release.
- The harness `Artifact` tool has no plumbing but uploads every screen to claude.ai.
  Screens here will contain employer code (Bupa DTOs, schemas, design screenshots).
  Rejected for that reason.

Decision: fork the companion's server (MIT, superpowers 6.3.0, © Jesse Vincent) into
this skill and redesign the frame and the policy.

## Invocation

- `cerebro` or `cerebro <topic>` starts a session.
- Mid-conversation offer, **once per conversation, as its own message**, when a
  question would genuinely be clearer seen than read. A "no" means never again in that
  conversation. The offer message carries nothing else — no question, no summary.
- Not a layer for other skills: `grilling`/`brainstorming` are untouched. If the offer
  turns out to fire too often or too rarely, that is a SKILL.md edit, not a redesign.

## Stance (from grilling, kept verbatim in spirit)

1. Walk every branch of the decision tree, resolving dependencies one by one.
2. One question per message. Wait for the answer.
3. Every question comes with a recommended answer and the reason.
4. Facts findable in the environment (files, git, tools, docs) are looked up, never
   asked. Decisions are the user's — put each one to them and wait.
5. Nothing is acted on until the user confirms shared understanding.

## Per-question surface

Every question is asked in the **terminal**, always. The browser is the exhibit; the
terminal is the record and the primary feedback channel. Per question, the test is:
*would the user understand this better by seeing it than reading it?*

Use the browser when the content is something to look at:

- referenced images ("design 2") — shown labelled so they can be named
- two or more code shapes compared — DTO ↔ zod ↔ Prisma model, old vs new interface
- structures — endpoint tables, field lists, event chains, module graphs, state machines
- UI mockups and layout comparisons
- the decision tree itself, when the user asks "where are we"

Keep to the terminal when the answer is words: scope, naming, wording, a yes/no with
no shape to look at, tradeoff lists that fit in a table.

A technical *topic* does not force the browser; a technical *shape* earns it.

## Images are files

Claude cannot re-emit an image pasted into the terminal. The skill states this at
session start. Images to be shown must exist as files:

- the user drops them into the session's `inbox/`, or
- drags a file into the terminal; Claude copies the path into `inbox/`.

## The tab

Two panes.

**Left, persistent — the decision tree.** Rendered by the frame from
`state/tree.json`, which Claude rewrites after every answer. Node states: `resolved`
(shows the chosen option), `current`, `pending`. Nesting allowed (a decision that only
exists because of a parent's answer sits under it). One source of truth: the same file
generates the decision record at the end.

```json
{
  "topic": "Deviza backend storage",
  "nodes": [
    { "id": "source", "title": "Rate source", "state": "resolved",
      "chosen": "MNB XML feed", "rejected": [{"option": "ECB", "why": "no HUF base"}],
      "children": [
        { "id": "cadence", "title": "Fetch cadence", "state": "current" }
      ] },
    { "id": "storage", "title": "Table shape", "state": "pending" }
  ]
}
```

**Right — the current screen.** One HTML fragment per question, written to `content/`
under a fresh semantic filename (`rate-source.html`, `rate-source-v2.html`). The server
serves the newest file and wraps fragments in the frame. Components the frame provides:

| component | markup | purpose |
|---|---|---|
| options | `.options > .option[data-choice]` (+ `data-recommended`, container `data-multiselect`) | A/B/C choices; recommended badge |
| gallery | `.gallery > figure > img[src=/inbox/…] + figcaption` | labelled reference images |
| compare | `.compare > .pane > .pane-title + pre` | N code shapes side by side |
| table, pros/cons | plain `<table>`, `.pros-cons` | as in the companion |
| mermaid | `<pre class="mermaid">` | flows, ER, sequence; loaded from CDN, degrades to raw text offline |
| note | provided by the frame, always visible | free text → `events` |
| typography | `h2`, `h3`, `.subtitle`, `.label`, `.section` | as in the companion |

Clicks and notes are appended as JSON lines to `state/events`; the file is cleared when
a new screen is pushed. Claude reads it on its next turn and merges it with the
terminal reply; the terminal reply wins on conflict.

When the next question is terminal-only, push a `waiting-N.html` screen so the tab does
not show a stale, already-answered choice.

## Session layout

```text
~/.cerebro/sessions/<project-slug>/<YYYY-MM-DD>-<topic-slug>/
  content/      screens (HTML fragments), newest is served
  inbox/        user-supplied images, served at /inbox/*
  state/
    server-info   startup JSON (port, url with key, dirs)
    server-stopped  present after shutdown
    tree.json     decision tree, rewritten by Claude
    events        browser clicks + notes (JSONL), cleared per screen
  decisions.md  written at the end
```

`<project-slug>` is the basename of the current working directory. Nothing is ever
written inside a repo.

## Ending

When shared understanding is reached, Claude writes `decisions.md` from `tree.json`:
topic, date, then per decision — chosen option, rejected options with the reason,
open follow-ups if any — and prints the path. Then it stops. It does not invoke
`writing-plans` or any implementation skill; if the user wants to build, that is the
next request.

## Server changes vs the fork

- Rename `brainstorm` → `cerebro` in env vars (`CEREBRO_IDLE_TIMEOUT_MS`, …), the
  client global (`window.cerebro`), default directories and messages.
- Default session root `~/.cerebro/sessions/<project-slug>/<date>-<topic>/`;
  `--session-dir <path>` overrides. `--project-dir` is dropped.
- New route `/inbox/*` serving `inbox/` (same auth cookie, same path-traversal guard
  as `/files/*`).
- On every push, the server reads `state/tree.json` and injects it into the frame's
  sidebar; a missing or invalid file renders an empty sidebar, never an error.
- The frame's note box posts `{"type":"note","text":…}` over the existing WebSocket;
  the server appends it to `events` like a click.
- Unchanged: session key in URL + cookie, WebSocket origin check, owner-death
  watchdog, idle timeout (4 h), `--open`, `--host`/`--url-host`, fragment-vs-full-
  document detection, newest-file-wins.

## Files

```text
~/dotfiles/claude/skills/cerebro/
  SKILL.md              stance, triggers, offer rule, loop, ending
  visual-guide.md       server start/stop, components, fragment recipes, events, tree.json
  DESIGN.md             this file
  scripts/
    server.cjs
    frame-template.html
    helper.js
    start-server.sh
    stop-server.sh
```

`install.sh`: `link "claude/skills/cerebro" "$HOME/.claude/skills/cerebro"`. The
existing untracked `grilling` and `grill-me` skills move into the repo the same way.

## Verification

1. Start the server, push one screen using every component, click an option, type a
   note; confirm `events` has both and the sidebar reflects `tree.json`.
2. Change `tree.json`, push a new screen; sidebar updates, `events` was cleared.
3. Drop an image in `inbox/`, reference it from a gallery; it renders.
4. Kill the server; restart with the same `--session-dir`; the open tab reconnects.
5. Dogfood: run a real `cerebro` session on an actual decision and fix what chafes.

## Out of scope

- Editing `grilling`, `grill-me` or `superpowers:brainstorming`.
- Any spec/plan artefact beyond `decisions.md`.
- Vendoring mermaid. The CDN script is version-pinned with SRI and the page has a CSP
  (`default-src 'self'`, script only from `cdn.jsdelivr.net`); a compromised package at
  that exact hash is the accepted residual risk. Vendoring would remove it at the cost of
  ~3 MB in the dotfiles repo.
- Syntax highlighting in `compare` panes (plain `<pre>`; revisit if it chafes).

## Follow-ups (from the 2026-08-26 build review)

Known rough edges, none blocking. Fix when they chafe.

- `server.cjs` injects `helper.js` with a string `replace` on `</body>` — same `$`-pattern hazard as the one fixed in `wrapInFrame`; inert while `helper.js` contains no `$`. Use a function replacer if it ever does.
- A `tree.json` change reloads the whole tab (discarding an unsent note); broadcasting the tree and re-rendering `#tree` in place would be gentler.
- `serveFileFrom` accepts `CEREBRO_OWNER_PID_HINT` like `01` (regex passes); `kill -0` EPERM is treated as dead — both fail closed.
- `tests/frame.test.js` is presence-only for CSS; visual correctness is covered by the demo (`demo/run-demo.sh`) and use.
- The shell test's port-reuse check depends on the JSON key order `server.cjs` emits.
- `INBOX_DIR` is exported from `server.cjs` but unused.
- Stale screen files (`-v2`, `-v3`) are never cleaned up — deliberate, they are the record.
