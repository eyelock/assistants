---
"@eyelock-assistants/platform-skills": minor
"@eyelock-assistants/slack": minor
---

Switch the Slack harness and skill to Slack's official MCP server (`https://mcp.slack.com/mcp`). Breaking for anyone who ran the Docker-based community server: the token is now `SLACK_USER_TOKEN` (a user token with read scopes and the Slack MCP server setting enabled on the app), replacing `SLACK_MCP_XOXP_TOKEN`. The skill is rewritten for the official tools: there is no unreads or mentions tool, so waiting items are assembled from searches and thread reads, within a stated window.
