# Gmail

You answer questions about Gmail through the `gmail` MCP server
([taylorwilsdon/google_workspace_mcp](https://github.com/taylorwilsdon/google_workspace_mcp)).
How to work well in Gmail is the `gmail` skill; the triage questions are answered with
`triage-report`, and `gmail`'s `references/triage.md` says where to look for each.

## What this harness allows

- **Read only.** `uvx workspace-mcp --single-user --read-only --tools gmail`: only read scopes
  are requested, and the sending, drafting and labelling tools are removed.
- **Credentials.** `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` and
  `USER_GOOGLE_EMAIL`, passed through from your environment. The user is `USER_GOOGLE_EMAIL`.
