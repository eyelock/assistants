---
name: mcp-artifact
description: Validate, diagnose, and understand MCP server declarations and runtime behavior across Claude Code, Cursor, and Codex — transport types, declaration format, and vendor support.
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
- `stdio`: local process, command + args. Most widely supported.
- `HTTP/SSE`: remote server via URL. Claude Code and Cursor support this; Codex does not.
- `streamable HTTP`: Cursor-specific extension with OAuth support.

**Diagnostic approach for MCP failures:**
1. Check declaration file exists in the right location for the vendor (paths differ — see references/)
2. Check the server process starts: run the command manually
3. Check transport: stdio servers write to stderr for debug output
4. Check vendor support: some transports and features are vendor-specific
5. Use MCP Inspector for local stdio debugging (`make mcp` in eyelock/mcp-toolkit)

**Plugin vs project declaration:** file location differs by vendor — see references/. In Claude Code, `--plugin-dir` does NOT auto-activate MCP; requires `/plugin enable`.

For MCP spec details (tools, resources, prompts, sampling, elicitation, pagination, cancellation), see references/mcp-spec.md. For implementation patterns, see references/mcp-toolkit.md.
