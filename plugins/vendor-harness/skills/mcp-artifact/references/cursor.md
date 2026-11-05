# Cursor — MCP Reference

Docs: https://cursor.com/docs/context/mcp
      https://cursor.com/docs/reference/plugins

## Declaration Files

Plugin: mcp.json at plugin root  (NO dot prefix — differs from Claude's .mcp.json;
        auto-discovered, or point at it with "mcpServers" in .cursor-plugin/plugin.json)
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

## ynh Export

ynh writes both `.cursor/mcp.json` (project) and `mcp.json` at the plugin root, no dot
(fixed in eyelock/ynh#198 / #202; see known-gaps in vendor-adapters). A hand-written plugin
that ships only `.mcp.json` still needs the no-dot `mcp.json` for Cursor.
