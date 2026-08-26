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

**Not a layer.** Cerebro is its own session. Do not bolt a Cerebro screen onto a running
`grilling` or `brainstorming` conversation — if the user wants the tab, start a Cerebro
session and carry the decisions made so far into its first `tree.json`.

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
3. Write the first `state/tree.json` with the Write tool — never a heredoc — (see
   visual-guide.md): every decision you can already see as `pending`, the first as
   `current`.
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
   `state/server-stopped` does not, and `kill -0 $(cat state/server.pid)` succeeds — else
   restart with `start-server.sh --session-dir <session_dir>`, same port, tab reconnects).
   Write a content fragment to `screen_dir/<semantic-name>.html` with the Write tool (never a
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
