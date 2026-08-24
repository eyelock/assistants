---
name: mcp-artifact
description: Validate, diagnose, and understand MCP server declarations and runtime behavior across Claude Code, Cursor, Codex, and Copilot CLI — transports, declaration format, and vendor support.
---

Use this skill when working with MCP server declarations — validating configuration, diagnosing startup or connection failures, or understanding what each vendor supports.

**Declaration format (shared across vendors):**
```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@scope/server"],
      "env": {"KEY": "value"}
    }
  }
}
```

**Transport types:**
- `stdio`: local process, command + args. Most widely supported. Copilot also accepts `local`
  as an alias — emit `"type": "stdio"`, which every vendor understands.
- `HTTP/SSE`: remote server via URL. Claude Code, Cursor, and Copilot CLI support this; Codex does not.
- `streamable HTTP`: Cursor extension with OAuth support; Copilot's `http` type is also
  streamable HTTP.

**Copilot-only key:** `tools` (e.g. `["*"]`) filters which of a server's tools are exposed.
Other vendors ignore it.

**Diagnostic approach for MCP failures:**
1. Check declaration file exists in the right location for the vendor (paths differ — see references/)
2. Check the server process starts: run the command manually
3. Check transport: stdio servers write to stderr for debug output
4. Check vendor support: some transports and features are vendor-specific
5. Use MCP Inspector for local stdio debugging (`make mcp` in eyelock/mcp-toolkit)

**Plugin vs project declaration:** file location differs by vendor — see references/. In Claude Code, `--plugin-dir` does NOT auto-activate MCP; requires `/plugin enable`. In Copilot CLI, an installed plugin is a snapshot — reinstall after editing `.mcp.json`, or iterate with `copilot --plugin-dir ./my-plugin`.

**Conflict resolution:** Claude, Cursor, and Copilot all resolve duplicate server names
last-wins. Copilot's order is user config → plugins (install order) → `--additional-mcp-config`,
and it warns when a later plugin displaces an earlier server.

For MCP spec details (tools, resources, prompts, sampling, elicitation, pagination, cancellation), see references/mcp-spec.md. For implementation patterns, see references/mcp-toolkit.md.
