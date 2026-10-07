# GitHub tools (official server, read-only endpoint)

For exact parameters and return fields, check each tool's own description; only what is known
is listed.

| Tool | What it is for | Notes |
|---|---|---|
| `get_me` | The signed-in user's login | Call first |
| `list_notifications` | Notifications with a `reason` | Needs the `notifications` toolset (not a default) |
| `search_pull_requests` | PRs by qualifier | Results are summaries |
| `search_issues` | Issues by qualifier | Same qualifiers |
| `pull_request_read` | One PR: review state, checks | Where requested reviewers, reviews and checks are read |
| `issue_read` | One issue and its comments | Used to see whether the user answered |

## Toolsets

The harness sends `X-MCP-Toolsets: context,issues,pull_requests,notifications`. `context`
carries `get_me`. The default toolsets do not include notifications, so it is named explicitly.

## Qualifiers

`review-requested:@me`, `author:@me`, `assignee:@me`, `mentions:@me`, `is:open`, `repo:`,
`org:`.

## Write tools: none

The read-only endpoint exposes no write tool. If the user wants a comment, review, merge or
re-run, that is `gh-cli`, and only when they asked.

## Auth

`Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}`. Use a token with read access only.
