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

If you start the server through a wrapper script (an extra process layer), the wrapper must
export `CEREBRO_OWNER_PID_HINT=<pid of the coding-agent harness>`; otherwise the
owner-death watchdog stops the server ~60 s later. Calling `start-server.sh` directly from
the Bash tool needs nothing.

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
helper script). Start with `<!DOCTYPE` or `<html` only if you need the whole page. A full
document bypasses the frame entirely — no sidebar, no note box, only the reconnect script
is injected — so use it only for a screen that deliberately needs none of those. Use the
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

Files must already be in `inbox/`. Name them so the caption and the filename agree. They
must be regular files — a symlink or Finder alias is refused with a 404.

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

Mermaid loads from a CDN; offline the block shows its source text. The script is
version-pinned with an integrity hash and the page carries a CSP that blocks any other
origin, but a screen still runs third-party code next to employer content — keep that in
mind before pasting anything you would not paste into a browser tab.

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
  ],
  "followUps": ["Revisit the JSON column option if write volume triples"]
}
```

- `state`: `resolved` (✓, shows `chosen`) · `current` (▶, exactly one) · `pending` (○).
- `children`: decisions that exist only because of the parent's answer.
- Add nodes as answers reveal them; never delete one — mark it `resolved` with
  `"chosen": "n/a — <why it vanished>"` so the record stays honest.
- `followUps`: things the user deferred; they become the *Open follow-ups* section of
  `decisions.md`.

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
- <each entry of `followUps`, or "none">
```

Number top-level nodes in order; children as `n.m`. Copy `rejected[].why` verbatim — it is
the part people forget.
