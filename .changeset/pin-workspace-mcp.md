---
"@eyelock-assistants/gmail": patch
"@eyelock-assistants/google-calendar": patch
"@eyelock-assistants/google-drive": patch
"@eyelock-assistants/platform-skills": patch
---

Pin the Google Workspace MCP server to `workspace-mcp@2.1.0`. Unpinned, `uvx` fetched whatever version was newest each time the harness started, for a server that holds the user's Google OAuth credentials.
