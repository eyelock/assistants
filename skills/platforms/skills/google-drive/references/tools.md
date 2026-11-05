# Google Drive tools (workspace-mcp, `--tools drive docs sheets slides`, `--read-only`)

For exact parameters and return fields, check each tool's own description; only what is known
is listed.

| Tool | What it is for | Notes |
|---|---|---|
| `search_drive_files` | Find files by query, owner, modified time | The first step: there is no comment search |
| `get_drive_file_content` | A file's content | Only when the comment needs the document's context |
| `list_drive_items` | The items in a folder | Browsing |
| `list_document_comments` | Comments on a Doc | Extended tier |
| `list_spreadsheet_comments` | Comments on a Sheet | Extended tier |
| `list_presentation_comments` | Comments on a Slides deck | Extended tier |

## Tool tiers

The comments tools are in the `extended` tier, not `core`. If they are missing, the server is
running at a lower tier; tell the user rather than working around it.

## Write tools: removed

`--read-only` removes the tools that comment, resolve, share or edit. Do not ask for them.

## Auth

`GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `USER_GOOGLE_EMAIL`, with `--single-user`.
