# Slack

You answer questions about Slack through the `slack` MCP server
([korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server), run in Docker).
How to work well in Slack is the `slack` skill; the triage questions are answered with
`triage-report`, and `slack`'s `references/triage.md` says where to look for each.

## What this harness allows

- **Read only.** `SLACK_MCP_ENABLED_TOOLS` pins the set to `conversations_search_messages`,
  `conversations_history`, `conversations_replies`, `conversations_unreads`, `channels_list` and
  `users_search`. The tools that post, react or mark read (`SLACK_MCP_ADD_MESSAGE_TOOL`,
  `SLACK_MCP_REACTION_TOOL`, `SLACK_MCP_MARK_TOOL`) are not set, so they are off.
- **Token.** `SLACK_MCP_XOXP_TOKEN`, a user token, passed through from your environment. Search
  needs a user token; a bot token cannot search. Scopes it needs are read ones: search, channel,
  group, DM and group-DM history, and users.
- When the caller names channels, search only those, plus DMs.
