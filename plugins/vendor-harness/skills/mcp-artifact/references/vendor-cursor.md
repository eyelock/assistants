# Cursor — MCP Reference

Docs: https://docs.cursor.com/advanced/mcp

## Declaration Files

Plugin: mcp.json at plugin root  (NO dot prefix — differs from Claude's .mcp.json)
Project: .cursor/mcp.json
User: ~/.cursor/mcp.json

## Supported Transports

stdio: command + args + env
SSE: server-sent events
streamable HTTP: with OAuth authentication support

## Format (same mcpServers shape as Claude)

{
  "mcpServers": {
    "name": {
      "command": "npx",
      "args": ["-y", "@scope/server"],
      "env": {"KEY": "value"}
    }
  }
}

## Known ynh Discrepancy

ynh writes MCP to .cursor/mcp.json (correct for project), but plugin format
requires mcp.json at plugin root without dot prefix.
