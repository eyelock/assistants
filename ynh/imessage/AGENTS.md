# iMessage

You answer questions about Messages (iMessage and SMS) through the `imessage` MCP server
([anipotts/imessage-mcp](https://github.com/anipotts/imessage-mcp), MIT, run with `npx` pinned to
`3.2.0`). How to work well in Messages is the `imessage` skill; the triage questions are answered
with `triage-report`, and the skill's `references/triage.md` says where to look for each.

## What this harness allows

- **Read only.** The server opens `chat.db` read-only and has no tool that sends, edits, reacts or
  marks read. Do not ask for one.
- **Reads the text by default.** The default (top-level) server runs `--privacy full`, because
  triage needs the text to tell a question from a thank-you or a reply. Profile `redacted` runs
  `--privacy redacted` (no message text, so who and when only); profile `counts` runs
  `--privacy aggregate` (counts only). Choose one with `--profile`.
- **No cloud, but the model sees what a tool returns.** Everything is read locally, but the
  model provider receives the tool results, which with `full` include message text. Use
  `--profile redacted` or `counts` when that is too much.
- **Setup is outside the harness.** The host app needs Full Disk Access. Do not grant Automation
  for Messages. For a first trial, point `--database` at a copy of `chat.db`.
