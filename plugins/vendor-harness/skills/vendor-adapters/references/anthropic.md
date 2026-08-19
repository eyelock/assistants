# Claude Code (Anthropic) — Vendor Reference

## Documentation URLs

- CLI Reference: https://code.claude.com/docs/en/cli-reference
- Plugins Overview: https://code.claude.com/docs/en/plugins
- Plugins Reference: https://code.claude.com/docs/en/plugins-reference
- Plugin Marketplaces: https://code.claude.com/docs/en/plugin-marketplaces
- Hooks Guide: https://code.claude.com/docs/en/hooks-guide
- MCP Servers: https://code.claude.com/docs/en/mcp
- Settings: https://code.claude.com/docs/en/settings
- Subagents: https://code.claude.com/docs/en/sub-agents
- Official Plugins: https://github.com/anthropics/claude-plugins-official

## Plugin Format

Manifest: `.claude-plugin/plugin.json`
Only `name` is required. Optional: `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`,
`displayName`, `metadata`, `$schema`, `dependencies`, `defaultEnabled`, `channels`,
`experimental.themes`, `experimental.monitors`.

Component pointers in manifest (paths relative to plugin root):
- `skills` — path to skills directory; ADDS TO the default `skills/` scan
- `commands` — path to commands directory (legacy, prefer skills); REPLACES default scan
- `agents` — path to agents directory; REPLACES default scan
- `workflows` — path to workflows directory; REPLACES default scan
- `outputStyles` — path to output styles; REPLACES default scan
- `hooks` — path to hooks config or inline object; MERGES with default
- `mcpServers` — path to MCP config or inline object; MERGES with default
- `lspServers` — path to LSP config or inline object; MERGES with default
- `userConfig` — user-configurable options (substituted into configs)

Single-skill plugin convention: a `SKILL.md` at the plugin root (no `skills/` dir) is auto-loaded.
`claude plugin init` scaffolds a skills-directory plugin that auto-loads without a marketplace/install step.

## Plugin Directory Structure

```
plugin-root/
  .claude-plugin/plugin.json    (manifest, only name required)
  skills/<name>/SKILL.md        (agent skills)
  commands/<name>.md            (legacy skills)
  agents/<name>.md              (subagents)
  workflows/<name>.json         (workflows)
  monitors/monitors.json        (background monitors)
  hooks/hooks.json              (hook config)
  .mcp.json                     (MCP servers)
  .lsp.json                     (LSP servers)
  bin/                          (executables added to PATH)
  settings.json                 ("agent" and "subagentStatusLine" keys supported)
```

## Hook Events (~30)

SessionStart, Setup, UserPromptSubmit, UserPromptExpansion, PreToolUse, PermissionRequest, PermissionDenied,
PostToolUse, PostToolUseFailure, PostToolBatch, Notification, SubagentStart, SubagentStop,
TaskCreated, TaskCompleted, Stop, StopFailure, TeammateIdle, InstructionsLoaded,
ConfigChange, CwdChanged, DirectoryAdded, FileChanged, WorktreeCreate, WorktreeRemove,
PreCompact, PostCompact, Elicitation, ElicitationResult, MessageDisplay, SessionEnd

## Hook Types

command, http, prompt, agent, mcp_tool

Hooks can also be declared directly in Skill frontmatter and Subagent frontmatter,
not just hooks.json/settings.json.

## Hook Format (hooks/hooks.json or settings.json)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "/path/to/script.sh", "timeout": 600}
        ]
      }
    ]
  }
}
```

## MCP Format (.mcp.json at plugin root or project root)

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

## Marketplace Format (.claude-plugin/marketplace.json)

```json
{
  "name": "marketplace-name",
  "owner": {"name": "Org"},
  "plugins": [
    {"name": "plugin-name", "source": "./plugins/plugin-name", "description": "...", "version": "1.0.0"}
  ]
}
```

## Key CLI Flags

- `--plugin-dir <path>` — load plugin for session (repeatable)
- `--add-dir <path>` — grant read access to directory
- `--append-system-prompt <text>` — inject instructions
- `--bare` — skip auto-discovery of hooks, skills, plugins, MCP
- `--mcp-config <path>` — load MCP servers from file
- `--permission-mode <mode>` — default, auto, plan, dontAsk, bypassPermissions
- `--dangerously-skip-permissions` — skip tool execution prompts
- `--plugin-url <url>` — load a hosted `.zip` plugin for the session

## Settings Governance Keys (new)

`strictKnownMarketplaces`, `blockedMarketplaces`, `allowedChannelPlugins`,
`disableCommandPluginSources`, `disableBundledSkills`, `disableAllHooks`

## Known Limitations for ynh

- `--plugin-dir` auto-activates skills/commands but NOT hooks/MCP (need `/plugin enable` + `/reload-plugins`)
- Plugin `settings.json` supports `agent` and `subagentStatusLine` keys (not hooks)
- Claude doesn't read AGENTS.md natively — export writes CLAUDE.md with `@AGENTS.md` import to bridge this
- Environment vars available: `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`
