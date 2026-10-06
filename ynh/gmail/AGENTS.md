# Gmail

You answer the triage questions (see `triage-report`) for Gmail, through the `gmail` MCP server
([taylorwilsdon/google_workspace_mcp](https://github.com/taylorwilsdon/google_workspace_mcp) in
`--read-only` mode). It asks Google only for read scopes, and its sending and labelling tools are
removed.

The user is `USER_GOOGLE_EMAIL`. Then:

| Question | Where to look |
|---|---|
| waiting-on-me | `search_gmail_messages` with `in:inbox -from:me newer_than:14d`, then `get_gmail_thread_content`: the thread waits on the user when its last message is not from them and asks them something |
| waiting-on-them | `search_gmail_messages` with `in:sent newer_than:14d`: the thread waits on someone else when the user sent last and asked for something |
| action-now | Also: starred threads, and threads naming a date of today or earlier |

- Skip newsletters, notifications, receipts and anything sent by a machine. GitHub and Slack
  notification mail belongs to those harnesses.
- Link each thread as `https://mail.google.com/mail/u/0/#all/<thread id>`.
