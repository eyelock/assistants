# Slack tools (official server, mcp.slack.com)

Read-only token: exactly these eight tools, all `readOnlyHint`. Parameters listed are the ones
that matter; all verified live unless marked.

| Tool | What it is for | Notes |
|---|---|---|
| `slack_search_public_and_private` | Search messages in channels, private channels, DMs and group DMs | `keywords` (array of single words or quoted phrases, AND'd), `filters` (modifier string), `natural_language_query` (pass `""`), `limit` (max 20), `cursor`, `sort` (`score` or `timestamp`), `sort_dir`, `include_context` (default true: set false for short output), `include_bots`, `channel_types` (`public_channel,private_channel,mpim,im`), `response_format` (`concise`), `after`/`before` (unix seconds) |
| `slack_search_public` | The same, public channels only | Same parameters except `channel_types`; prefer the tool above, which covers DMs |
| `slack_search_users` | Find users | `keywords`, `natural_language_query` both required; result has `User ID`, `Timezone` |
| `slack_search_channels` | Find channels by name, to get an ID | `keywords` and `natural_language_query` both required; `channel_types` defaults to public only |
| `slack_read_channel` | Messages in a channel or DM, newest first | `channel_id` (a `D...` ID or a user ID works for a DM), `limit` (max 100), `oldest`, `latest` (ts), `cursor`; shows `Message TS` and `Reactions` |
| `slack_read_thread` | Parent and all replies | `channel_id`, `message_ts` (the parent, with the decimal point), `limit`, `cursor`; "No thread messages" for a message with no replies |
| `slack_list_user_channels` | The user's channels | `types` (add `im,mpim` for DMs; default excludes them), `limit` (max 200), `name_prefix`; lists IDs and member IDs, not unread state |
| `slack_list_channel_members` | Members of a channel | Up to 30 per page; does not support DMs |

## Search result shape

`Channel: #name (ID: C...)` or `Channel: DM (ID: D...)` with `Participants`, then `From`, `Time`,
`Message_ts`, `Reply count` (parents only), `Permalink: [link](url)`, `Text`. With context on,
`Context before/after` lines follow. The reply ends with `pagination_info`. `concise` returns
one line per message and no permalink.

## Not available

- No unreads, no mentions, no whoami tool. No tool lists saved items (`is:saved` search
  modifier is listed in the tool description; unverified).
- Write tools (send, draft, schedule, react) are absent with read scopes. A tool description
  may still mention `slack_send_message`: never call it.
- `slack_read_user_profile` is named in descriptions but was not exposed to a read-only token.

## Auth

`SLACK_USER_TOKEN`, a user token (`xoxp-`), sent as `Authorization: Bearer`. The Slack app
needs its Slack MCP server access setting enabled and read user scopes: `search:read`,
`search:read.public`, `search:read.private`, `search:read.im`, `search:read.mpim`,
`search:read.users`, `channels:history`, `groups:history`, `im:history`, `mpim:history`,
`channels:read`, `groups:read`, `im:read`, `mpim:read`, `users:read`. A bot token cannot search.
