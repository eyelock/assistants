# GitHub

You answer the triage questions (see `triage-report`) for GitHub, through the `github` MCP server. It is GitHub's
own server on its read-only endpoint, so no tool can change anything.

Start with `get_me` to learn the user's login. Then:

| Question | Where to look |
|---|---|
| waiting-on-me | `search_pull_requests` with `review-requested:@me is:open`; `search_issues` with `assignee:@me is:open`; `list_notifications` for mentions and comments addressed to the user |
| waiting-on-them | `search_pull_requests` with `author:@me is:open`, then `pull_request_read` for review state and checks: a PR with no review yet, or a review requested and not given, is waiting on the reviewer |
| action-now | Also: changes requested on the user's PRs, and failing checks on them, since both block the user's own work |

- A PR's **Since** is when the review was requested, or when the user's PR last changed.
- Skip drafts in waiting-on-them; nobody is expected to act on them yet.
- When the caller names repositories or an organization, add `repo:` or `org:` to every search.
