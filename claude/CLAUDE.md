# Output formatting

I read your output in a terminal (Ghostty). Claude Code's markdown renderer
collapses or drops several constructs, so prefer the ones that survive:

- **Headings: `##` only.** `###` and `####` render identically to `##`, and `#`
  renders italic + underlined, which reads as *weaker* than `##`. For a
  sub-point, use a bold lead-in on its own line instead of a deeper heading.
- **No `---`.** Horizontal rules print as a literal dim `---` and read as
  leftover markup. A blank line is enough.
- **No footnotes** (`[^1]`) and **no task lists** (`- [ ]`) — both print raw.
- **Always tag code fences with a language.** Fenced code gets no background
  and no border in the terminal, so syntax colour is the only cue that a block
  is code rather than prose.
- **Tables, blockquotes, and fenced code render well.** Reach for these when
  something needs to stand out.
- Inline `code`, **bold**, *italic* and ~~strikethrough~~ all render correctly.
