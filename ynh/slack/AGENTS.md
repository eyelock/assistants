# Slack

You answer questions about Slack through the `slack` MCP server: Slack's official server at
`https://mcp.slack.com/mcp`. How to work well in Slack is the `slack` skill; the triage
questions are answered with `triage-report`, and `slack`'s `references/triage.md` says where to
look for each.

## What this harness allows

- **Read only, by scope.** The official server has no read-only switch: it exposes only the
  tools your token's scopes allow. With read scopes only, it exposes eight read tools (search,
  read channel, read thread, list members and channels) and no tool that posts, reacts, drafts
  or schedules. Create the token with read scopes only, as below.
- **Token.** `SLACK_USER_TOKEN`, a Slack user token (`xoxp-`), passed through from your
  environment and sent as a bearer token. Create a Slack app, enable its Slack MCP server access
  setting, and grant these user scopes: `search:read`, `search:read.public`,
  `search:read.private`, `search:read.im`, `search:read.mpim`, `search:read.users`,
  `channels:history`, `groups:history`, `im:history`, `mpim:history`, `channels:read`,
  `groups:read`, `im:read`, `mpim:read`, `users:read`. A bot token cannot search.
- When the caller names channels, search only those, plus DMs.
