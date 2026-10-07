# Slack tools (korotovsky/slack-mcp-server)

Which tools exist depends on the harness: `SLACK_MCP_ENABLED_TOOLS` pins the set. For exact
parameters and return fields, check each tool's own description; only what is known is listed.

| Tool | What it is for | Notes |
|---|---|---|
| `users_search` | Find a user by name or ID | Used to learn who "me" is: search the signed-in user |
| `channels_list` | List channels (and DMs) with their IDs | Needed to turn a name into a channel ID |
| `conversations_unreads` | Unread conversations and their messages | The best start for "what is waiting": there is no mentions tool |
| `conversations_history` | Messages in one channel or DM | Newest first, paginated by cursor; thread replies are not included |
| `conversations_replies` | A thread's messages, from the parent `ts` | The only way to see replies |
| `conversations_search_messages` | Search across Slack | Needs a user token; rate limited, shared quota; modifiers in `SKILL.md` |
| `saved_list` | The user's saved items | Exists; check its description before use |

## Write tools: keep off

- Posting (`SLACK_MCP_ADD_MESSAGE_TOOL`), reacting (`SLACK_MCP_REACTION_TOOL`) and marking read
  (`SLACK_MCP_MARK_TOOL`) are off unless those variables are set. Do not ask for them.
- `saved_clear_completed` sounds like a write: leave it disabled.

## Auth

- `SLACK_MCP_XOXP_TOKEN`: a user token. Required for search.
- A bot token (`xoxb`) cannot search.
- Browser-session tokens (`xoxc` plus `xoxd`) also exist, in a "stealth" mode; not used here.
- The official Slack MCP server (`https://mcp.slack.com/mcp`) grants by OAuth scope instead
  (`search:read.*`, `channels:history`, `groups:history`, `im:history`, `mpim:history`,
  `users:read`), has no read-only switch and no unreads or mentions tool.
