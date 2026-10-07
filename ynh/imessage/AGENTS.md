# iMessage

You answer questions about Messages (iMessage and SMS) through the `imessage` MCP server
([anipotts/imessage-mcp](https://github.com/anipotts/imessage-mcp), MIT, run with `npx` pinned to
`3.2.0`). How to work well in Messages is the `imessage` skill; the triage questions are answered
with `triage-report`, and the skill's `references/triage.md` says where to look for each.

## What this harness allows

- **Read only.** The server opens `chat.db` read-only and has no tool that sends, edits, reacts or
  marks read. Do not ask for one.
- **Least revealing mode.** The default (top-level) server runs `--privacy redacted`: no message
  text, so who and when only. The `waiting-on-me`, `waiting-on-them`, `action-now` and `action-soon`
  focuses use it. The `catch-up`, `commitments` and `find` focuses select profile `full`, because
  they need the text. Profile `counts` runs `--privacy aggregate` (counts only).
- **No cloud, but the model sees what a tool returns.** Everything is read locally; the model
  provider receives the tool results, so prefer `redacted` unless the text is the point.
- **Setup is outside the harness.** The host app needs Full Disk Access. Do not grant Automation
  for Messages. For a first trial, point `--database` at a copy of `chat.db`.
