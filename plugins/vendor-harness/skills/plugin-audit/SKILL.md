---
name: plugin-audit
description: Audit an entire plugin directory for cross-vendor readiness — walks all artifacts (skills, agents, MCP, hooks, startup context) and reports issues by vendor and priority.
---

Use this skill when you want to know: "is this plugin ready to ship to all three vendors?" It walks every artifact in a plugin directory and applies the relevant artifact skill validator to each, then produces a consolidated per-vendor report.

## Walk Order

1. **Manifests** — check for `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.ynh-plugin/plugin.json`, `.codex-plugin/plugin.json`. Note any missing vendor manifests. Check required fields per vendor.

2. **Skills** (`skills/*/SKILL.md`) — invoke skill-artifact for each. Check: frontmatter, description length, metadata demotion risk, directory layout.

3. **Agents** (`agents/*.md`) — invoke subagent-artifact for each. Check: frontmatter fields, vendor support (Codex has none), delegation assumptions.

4. **MCP** (`.mcp.json`, `mcp.json`) — invoke mcp-artifact. Check: file location per vendor (dot vs no-dot), transport types used, vendor support.

5. **Hooks** (`hooks/hooks.json`) — invoke hooks-artifact. Check: event names (PascalCase vs legacy camelCase), event coverage per vendor, hook types used.

6. **Startup context** (`CLAUDE.md`, `AGENTS.md`, `rules/`, `.cursorRules`) — invoke startup-context. Check: correct files present per vendor, rules format (.md vs .mdc), @-import workaround for Claude.

## Report Format

Produce a table per vendor showing readiness:

```
Claude Code:  ✓ ready | issues: [list]
Cursor:       ✓ ready | issues: [list]
Codex:        ✓ ready | issues: [list]
```

Then a prioritized issue list:

```
HIGH  [artifact] description — affects: Claude/Cursor/Codex
MED   [artifact] description — affects: Cursor
LOW   [artifact] description — affects: all
```

## Usage

Invoke directly on a plugin root:
- "Audit plugins/vendor-harness for cross-vendor readiness"
- "Is gitflow ready to ship to Codex?"

harness-advisor will route here when a user asks about overall plugin compatibility rather than a specific artifact problem.
