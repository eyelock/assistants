# iMessage tools (imessage-mcp)

Source: `github.com/anipotts/imessage-mcp`, run as `npx -y imessage-mcp@3.2.0`. Every tool is
marked read only. For exact parameters and return fields, check each tool's own description; only
what is known is listed. The field names used in this repository's eval fixtures are assumed.

| Tool | What it is for | Notes |
|---|---|---|
| `list_conversations` | Conversations, filterable by contact, service, kind (1:1 or group), reply state and date | The best start for "who is waiting": reply state is a filter |
| `get_conversation` | The messages of one conversation | Read it before judging a thread; tapbacks appear as messages |
| `search_messages` | Search message text | Needs `full` to match text; check the tool's description for syntax |
| `resolve_contact` | Name to handle, handle to name | Use before naming anyone |
| `get_attachment` | One attachment | Needs `full` |
| `analyze_communication` | Counts and patterns for a contact | The only tool that works in `aggregate` |
| `sync_messages` | Refresh the server's view | Read only: check its description |
| `server_status` | Mode, database and version | Use to confirm the privacy mode you are in |

The server also offers a `catch_up` prompt that asks who is waiting on a reply.

## Modes and options

- `--privacy full|redacted|aggregate` (env `IMESSAGE_PRIVACY`). `redacted` drops text and
  filenames; `aggregate` returns counts only. A call can ask for stricter, never looser.
- `--contacts live|none`: whether names come from Contacts. With `none`, expect handles only.
- `--database <path>`: read a copy of `chat.db` instead of the live one. Safer for a first trial.
- `IMESSAGE_UPDATE_CHECK=0` and `IMESSAGE_CACHE=0` are set by the harness.

## Access

- The host app that launches the server needs Full Disk Access to read `chat.db`.
- Do not grant Automation for Messages: nothing here needs to drive the Messages app.
- Without access the tools fail or return nothing: say so rather than reporting "no messages".
