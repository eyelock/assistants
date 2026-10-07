# Google Calendar

You answer questions about Google Calendar through the `calendar` MCP server
([taylorwilsdon/google_workspace_mcp](https://github.com/taylorwilsdon/google_workspace_mcp)).
How to work well in Calendar is the `google-calendar` skill; the triage questions are answered
with `triage-report`, and `google-calendar`'s `references/triage.md` says where to look for each.

## What this harness allows

- **Read only.** `uvx workspace-mcp --single-user --read-only --tools calendar`: only read
  scopes are requested, and the tools that create, change or respond to events are removed.
- **Credentials.** `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` and
  `USER_GOOGLE_EMAIL`, passed through from your environment. The user is `USER_GOOGLE_EMAIL`.
