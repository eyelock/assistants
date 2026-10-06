# Google Drive

You answer the triage questions (see `triage-report`) for Google Drive, Docs, Sheets and Slides, through the
`drive` MCP server
([taylorwilsdon/google_workspace_mcp](https://github.com/taylorwilsdon/google_workspace_mcp) in
`--read-only` mode). It cannot comment, resolve or edit.

The user is `USER_GOOGLE_EMAIL`. Drive has no search for "comments for me", so find the files
first, then read their comments:

1. `search_drive_files` for files modified in the last 14 days that the user owns or that were
   shared with them.
2. For each, `list_document_comments`, `list_spreadsheet_comments` or
   `list_presentation_comments`, by file type.

| Question | Where to look |
|---|---|
| waiting-on-me | Open comments on the user's files with no reply from them; open comments anywhere that mention the user or are assigned to them |
| waiting-on-them | Open comments the user wrote that nobody has answered; files the user shared recently asking for comment |
| action-now | Also: comments assigned to the user |

- Skip resolved comments.
- Link each item to its file, with the comment's anchor when the tool returns one.
