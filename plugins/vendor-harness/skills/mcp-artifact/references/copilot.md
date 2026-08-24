# GitHub Copilot CLI — MCP Reference

Docs: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers
      https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference

## Declaration Files

Plugin: `.mcp.json` at plugin root, or `.github/mcp.json`
        (or point at it from `plugin.json`: `"mcpServers": "./.mcp.json"`,
         or declare servers inline as an object under `mcpServers`)
Project: `.mcp.json` in any directory up to the repository root, or `.github/mcp.json`
User: `~/.copilot/mcp-config.json`
CLI: `--additional-mcp-config <path>`

## Supported Transports

| `type` | Meaning |
|--------|---------|
| `stdio` | local process — the standard MCP name; use this for portability |
| `local` | Copilot alias for `stdio` |
| `http` | remote, streamable HTTP transport |
| `sse` | legacy HTTP + Server-Sent Events; deprecated in the MCP spec, still accepted |

## Format

```json
{
  "mcpServers": {
    "playwright": {
      "type": "local",
      "command": "npx",
      "args": ["@playwright/mcp@latest"],
      "env": {},
      "tools": ["*"]
    },
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp",
      "headers": {"CONTEXT7_API_KEY": "YOUR-API-KEY"},
      "tools": ["*"]
    }
  }
}
```

Keys: `type`, `command`, `args`, `env`, `url`, `headers`, `tools`, `timeout` (milliseconds).

`tools` is Copilot-specific — it filters which of the server's tools are exposed. `["*"]`
means all. Claude Code and Codex have no equivalent and will ignore it.

## Portability Notes

- Copilot writes `"type": "local"` in its own examples; Claude Code and Codex expect either
  no `type` or `"stdio"` for a command-based server. Emit `"type": "stdio"` — Copilot accepts
  it and it is the only spelling all three vendors understand.
- Claude Code *requires* `type` to disambiguate url-based entries; Copilot requires it for
  remote servers too. Always set it explicitly on HTTP/SSE entries.
- No documented environment-variable interpolation syntax (`${env:NAME}` etc.). Cursor
  supports interpolation, Copilot does not document it — resolve secrets outside the file or
  rely on `~/.copilot/mcp-secrets/`.
- `${COPILOT_PLUGIN_DATA}` (aliased `${CLAUDE_PLUGIN_DATA}`) is a persistent writable
  directory unique to each installed plugin, usable in `env`.

## Precedence

**Last-wins**, unlike agents and skills: user config → plugin configs (install order) →
`--additional-mcp-config`. Two plugins declaring the same server name → the later install
wins, with a warning. Project-level MCP config takes precedence over user-level on name
conflicts.

Servers can be toggled with the `disabledMcpServers` / `enabledMcpServers` settings, or
`copilot plugins disable --mcp NAME`.

## Built-in Servers

`github` (read-only tools, scoped to the source repository) and `playwright` (localhost only)
are available out of the box and addressable from agent `tools` as `github/*`,
`playwright/<tool>`.

## Diagnostics

- `copilot mcp` manages server configuration.
- `copilot plugin list` shows installed plugins; `copilot mcp` manages servers directly.
- OAuth tokens and secret fallbacks live in `~/.copilot/mcp-oauth-config/` and
  `~/.copilot/mcp-secrets/`.
- An *installed* plugin's MCP config is a snapshot — reinstall after editing `.mcp.json`. Use
  `copilot --plugin-dir ./my-plugin` while iterating: it loads from the directory each run.
