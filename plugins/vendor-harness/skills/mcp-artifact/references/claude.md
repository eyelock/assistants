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
WebSocket: url with type: "ws" (remote servers)

"type" field is required to disambiguate url-based entries (http/sse/ws) from stdio.

## Reserved Server Names

workspace, claude-in-chrome, computer-use, and other built-ins are reserved —
a plugin/user MCP server cannot reuse these names.

## Inline Declaration

MCP servers can also be declared inline in plugin.json, not just in a
separate .mcp.json file.

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
