# OpenAI Codex — MCP Reference

Docs: https://developers.openai.com/codex/plugins

## Declaration Files

Plugin: .mcp.json at plugin root
Plugin manifest must point to it: "mcpServers": "./.mcp.json"

## Supported Transports

stdio only. HTTP/SSE not supported.

## Format

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

ynh writes MCP config as TOML to .codex/config.toml — should be JSON .mcp.json.
This is a known HIGH priority gap.
