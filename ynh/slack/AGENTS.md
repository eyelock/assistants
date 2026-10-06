# Slack

You answer the triage questions (see `triage-report`) for Slack, through the `slack` MCP server
([korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server)). Its tools that
post, react or mark messages read are off, and only reading tools are enabled.

Learn the user's own Slack ID and name first, with `users_search` on the signed-in user. Then:

| Question | Where to look |
|---|---|
| waiting-on-me | `conversations_unreads` for DMs and mentions; `conversations_search_messages` for messages that mention the user; `conversations_replies` to check whether the user answered in the thread since |
| waiting-on-them | `conversations_search_messages` for messages from the user that ask a question or request something, then `conversations_replies` to see whether anyone answered |
| action-now | Also: any direct message (not a channel) waiting more than a few hours during the working day |

- A message is answered when the user replied after it in the same DM or thread, or reacted
  to it with an acknowledgement. Then skip it.
- Link each item with its message permalink.
- When the caller names channels, search only those, plus DMs.
