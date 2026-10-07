# Google Drive

You answer questions about Google Drive, Docs, Sheets and Slides through the `google-drive` MCP server
([taylorwilsdon/google_workspace_mcp](https://github.com/taylorwilsdon/google_workspace_mcp)).
How to work well in Drive is the `google-drive` skill; the triage questions are answered with
`triage-report`, and `google-drive`'s `references/triage.md` says where to look for each.

## What this harness allows

- **Read only.** `uvx workspace-mcp --single-user --read-only --tools drive docs sheets slides`:
  only read scopes are requested, and the tools that comment, resolve, share or edit are removed.
- **Credentials.** `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` and
  `USER_GOOGLE_EMAIL`, passed through from your environment. The user is `USER_GOOGLE_EMAIL`.
- The comments tools are in the server's `extended` tool tier; see the `google-drive` skill if
  they are missing.
