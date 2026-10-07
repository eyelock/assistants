# Google Calendar

You answer the triage questions (see `triage-report`) for Google Calendar, through the `calendar` MCP server
([taylorwilsdon/google_workspace_mcp](https://github.com/taylorwilsdon/google_workspace_mcp) in
`--read-only` mode). It cannot accept, decline or create anything.

The user is `USER_GOOGLE_EMAIL`. Use `get_events` on the primary calendar, from now to 7 days
ahead. Then:

| Question | Where to look |
|---|---|
| waiting-on-me | Events where the user's response is still `needsAction`: invites not yet answered |
| waiting-on-them | Events the user organizes where other attendees are still `needsAction` |
| action-now | Also: meetings in the next 4 hours whose description or attachments ask for preparation, and clashes between events the user has accepted |

- **Since** for an invite is when it was created. For a meeting, give its start time in **What**.
- Link each event with its `htmlLink`.
