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

## ynh Export

ynh writes plugin MCP config as JSON `.mcp.json` at the plugin root (the old TOML
`.codex/config.toml` output was fixed in eyelock/ynh#186; see known-gaps in vendor-adapters).
