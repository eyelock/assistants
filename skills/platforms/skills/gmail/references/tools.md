# Gmail tools (workspace-mcp, `--tools gmail`, `--read-only`)

For exact parameters and return fields, check each tool's own description; only what is known
is listed.

| Tool | What it is for | Notes |
|---|---|---|
| `search_gmail_messages` | Search with Gmail operators | Hits are messages with a thread ID; operators in `SKILL.md` |
| `get_gmail_thread_content` | A whole thread, in order | Needed to see the last message and who sent it |
| `get_gmail_messages_content_batch` | Several messages at once | Cheaper than one call each |
| `list_gmail_labels` | The mailbox's labels | Use to learn which labels mark promotions and updates |

## Write tools: removed

`--read-only` removes the sending, drafting and labelling tools and requests read scopes only.
Do not ask for them.

## Auth

`GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `USER_GOOGLE_EMAIL`, with `--single-user`.
