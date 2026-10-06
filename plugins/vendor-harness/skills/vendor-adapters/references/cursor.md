# Cursor — Vendor Reference

## Documentation URLs

- Plugin Template: https://github.com/cursor/plugin-template
- Official Plugins Repo: https://github.com/cursor/plugins
- Marketplace: https://cursor.com/marketplace
- MCP Servers: https://cursor.com/docs/context/mcp (docs.cursor.com/advanced/mcp redirects here)
- Rules (.mdc format): https://cursor.com/docs/context/rules (docs.cursor.com/advanced/rules redirects here)
- CLI Install: https://cursor.com/cli
- Forum: .agents/ support: https://forum.cursor.com/t/support-for-agent-folder-compatibility/154167

Note: docs.cursor.com aggressively rate-limits programmatic access. Manual browsing may be needed.

## Plugin Format

Manifest: `.cursor-plugin/plugin.json`
Required fields: `name`, `version`, `description`.
Optional: `displayName`, `author`, `license`, `keywords`, `logo`.

## Plugin Directory Structure

```
plugin-root/
  .cursor-plugin/plugin.json   (manifest)
  skills/<name>/SKILL.md        (agent skills)
  rules/<name>.mdc              (rules with frontmatter)
  agents/<name>.md              (subagents)
  commands/<name>.md             (commands)
  hooks/hooks.json              (hook config)
  mcp.json                      (MCP servers — note: no dot prefix)
  scripts/                      (hook scripts)
  assets/                       (logos, icons)
```

## Hook Config Paths

- Plugin: `hooks/hooks.json` (at plugin root)
- Project: `.cursor/hooks.json`
- User: `~/.cursor/hooks.json`
- Enterprise: OS-specific `hooks.json` (e.g. `/Library/Application Support/Cursor/hooks.json`)

There is no `.cursor/settings.json` for hooks. Cursor can also load Claude Code hooks from
`.claude/settings*.json` when third-party configs are enabled (cursor.com/docs/reference/third-party-hooks);
see hooks-artifact's Cursor reference for the event mapping.

## Hook Types

command (default), prompt. No http, agent, or mcp_tool type.

## Hook Format — flat, camelCase, one format everywhere

```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      {"command": "./scripts/validate-shell.sh", "matcher": "rm|curl|wget"}
    ],
    "afterFileEdit": [
      {"command": "./scripts/format-code.sh"}
    ],
    "stop": [
      {"command": "./scripts/audit.sh"}
    ]
  }
}
```

The hooks docs require `"version": 1`; the plugin reference's example omits it.

CONFIRMED (cursor.com/docs/hooks, cursor.com/docs/reference/plugins): plugin and project
locations use the SAME flat/lowercase-camelCase format and event names — only the path
differs. ynh's Cursor adapter (`Cursor.GenerateHookConfig`) writes both
`.cursor/hooks.json` and plugin-root `hooks/hooks.json` with identical content.

## Hook Events (21: 18 agent, 2 Tab, 1 app lifecycle)

Full supported event list confirmed via docs: `sessionStart`, `sessionEnd`,
`preToolUse`, `postToolUse`, `postToolUseFailure`, `subagentStart`, `subagentStop`,
`beforeShellExecution`, `afterShellExecution`, `beforeMCPExecution`,
`afterMCPExecution`, `beforeReadFile`, `afterFileEdit`, `beforeSubmitPrompt`,
`preCompact`, `stop`, `afterAgentResponse`, `afterAgentThought` (plus Tab hooks
`beforeTabFileRead`/`afterTabFileEdit` and app-lifecycle `workspaceOpen`, not
currently mapped by ynh). ynh's canonical map covers 5 events — SessionStart
was added as `on_session_start` in eyelock/ynh#204; the rest remain unmapped.

## MCP Format

Project: `.cursor/mcp.json`
User: `~/.cursor/mcp.json`
Plugin: `mcp.json` (at plugin root, NO dot prefix — differs from Claude's `.mcp.json`)
FIXED: ynh writes both — `Cursor.GenerateMCPConfig` emits identical content to both paths.

```json
{
  "mcpServers": {
    "name": {
      "command": "npx",
      "args": ["-y", "@scope/server"],
      "env": {"KEY": "value"}
    }
  }
}
```

Supports: stdio, SSE, streamable HTTP transports. OAuth authentication supported.
Config interpolation supported: `${env:NAME}`, `${workspaceFolder}`, `${userHome}`.

## Marketplace Format (.cursor-plugin/marketplace.json)

```json
{
  "name": "cursor-plugins",
  "owner": {"name": "Cursor", "email": "plugins@cursor.com"},
  "metadata": {"description": "..."},
  "plugins": [
    {"name": "plugin-name", "source": "plugin-name", "description": "..."}
  ]
}
```

Install command: `/add-plugin` in editor

## Rules Format (.mdc)

Path: `.cursor/rules/<name>.mdc`
Legacy: `.cursorrules` (project root, deprecated but still read)

```yaml
---
description: Baseline coding standards
globs: "*.ts,*.tsx"
alwaysApply: true
---

- Prefer small, focused changes
- Write tests for new functions
```

Frontmatter fields: `description`, `globs` (file pattern), `alwaysApply` (boolean).
CONFIRMED (cursor.com/docs/advanced/rules): plain `.md` files in `.cursor/rules` are
silently ignored. ynh's Cursor adapter (`internal/vendor/cursor.go`,
`Cursor.TransformArtifact`) renames `.md` → `.mdc` and injects
`description`/`alwaysApply: true` frontmatter at copy time (both `ynh run` staging and
`ynh export`). No `globs` is emitted — ynh has no per-rule glob metadata to source it
from.

Rules tiers: Project (`.cursor/rules/*.mdc`, per-repo), User (Cursor settings, per-user),
Team (dashboard-managed, Team/Enterprise plans).

## Key CLI Details

- Binary: `agent` (installed via `curl https://cursor.com/install -fsS | bash`)
- Non-interactive: `agent -p "prompt"`
- Environment vars: `$CURSOR_PROJECT_DIR`, `$CURSOR_ENV_FILE`, `$CURSOR_WORKSPACE_DIR`

## What Cursor Supports That ynh Maps

- Skills: YES (skills/<name>/SKILL.md)
- Agents/subagents: YES (agents/<name>.md) — CONFIRMED (cursor.com/docs/subagents):
  reads `name`/`description` frontmatter (required — `description` drives delegation
  routing), plus optional `model`/`readonly`/`is_background`. ynh's delegate generator
  (`internal/assembler/delegates.go`) already emits `name`+`description`.
- Rules: YES (.cursor/rules/<name>.mdc) — FIXED: ynh now writes `.mdc` with frontmatter
- Commands: YES (commands/<name>.md)
- Hooks: YES — FIXED: ynh writes both `.cursor/hooks.json` (project) and `hooks/hooks.json` (plugin root), same format/event names in both
- MCP: YES — FIXED: ynh writes both `.cursor/mcp.json` (project) and `mcp.json` (plugin root, no dot)
- Scripts: YES (scripts/ — first-class plugin artifact type, e.g. hook scripts)
- Marketplace: YES (.cursor-plugin/marketplace.json)
- .agents/skills/: PARTIAL — Cursor reads `.agents/skills/` but NOT `.agents/rules/` or other subdirs

## Known ynh Discrepancies (as of 2026-08-19)

All four tracked discrepancies (eyelock/ynh#196, #197, #198, #200) are resolved as of
this note — see the FIXED/CONFIRMED markers above.
