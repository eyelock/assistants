# Claude Code — MCP Reference

Docs: https://code.claude.com/docs/en/mcp

## Declaration Files

Plugin: .mcp.json at plugin root  ({"mcpServers": {...}})
Project: .mcp.json at project root
User: ~/.claude/mcp.json
CLI: --mcp-config <path>

## Supported Transports

stdio: command + args + env
HTTP: url + headers (remote servers)

## Plugin Activation

--plugin-dir does NOT auto-activate MCP servers.
User must run /plugin enable and /reload-plugins after install.

## Environment Variables

${CLAUDE_PLUGIN_ROOT} — path to plugin directory
${CLAUDE_PLUGIN_DATA} — path to plugin data directory
Available in env field of MCP server declaration.

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
