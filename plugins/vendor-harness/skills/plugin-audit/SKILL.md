---
name: plugin-audit
description: Audit an entire plugin or marketplace for cross-vendor readiness — walks all artifacts (skills, agents, MCP, hooks, startup context, manifests) and reports issues by vendor and priority. Use before publishing, or when asked whether a plugin or marketplace will install and work on a vendor.
---

Use this skill when you want to know: "is this plugin ready to ship to every vendor?" It walks every artifact in a plugin directory and applies the relevant artifact skill validator to each, then produces a consolidated per-vendor report. Vendors covered: Claude Code, Cursor, Codex, GitHub Copilot CLI.

## Walk Order

1. **Manifests** — check for `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.agents/harness/plugin.json` (ynh; the deprecated `.ynh-plugin/plugin.json` still loads, with a warning), `.codex-plugin/plugin.json`. Note any missing vendor manifests. Check required fields per vendor.

   Copilot CLI needs no dedicated manifest directory — it falls back to `.claude-plugin/plugin.json` (after `.plugin/`, root `plugin.json`, and `.github/plugin/`). Verify the plugin `name` is kebab-case with no dots, or Copilot rejects it.

2. **Marketplace index** (repo-level, when auditing a marketplace repo) — check every `source` entry against the Claude ↔ Copilot support table in vendor-adapters. Copilot accepts only relative paths, `github`, and `url`: a `git-subdir`, `npm`, `archive`, or `command` source, or a non-kebab-case plugin name, fails the *entire* index for Copilot CLI, not just that entry. Flag as HIGH.

3. **Skills** (`skills/*/SKILL.md`) — invoke skill-artifact for each. Check: frontmatter, description length, metadata demotion risk, directory layout.

4. **Agents** (`agents/*.md`, `agents/*.agent.md`) — invoke subagent-artifact for each. Check: frontmatter fields, vendor support (Codex has none), delegation assumptions. Both extensions load in Copilot, so no renaming is needed; Copilot requires `description` but not `name`.

5. **MCP** (`.mcp.json`, `mcp.json`) — invoke mcp-artifact. Check: file location per vendor (dot vs no-dot), transport types used, `type` spelling (`stdio` is the portable one), vendor support.

6. **Hooks** (`hooks/hooks.json`, `hooks.json`) — invoke hooks-artifact. Check: nesting shape (three-level vs two-level), Copilot's required `"version": 1`, event names (PascalCase vs camelCase), event coverage per vendor, hook types used.

7. **Startup context** (`CLAUDE.md`, `AGENTS.md`, `rules/`, `.cursorRules`, `.github/copilot-instructions.md`, `.github/instructions/`) — invoke startup-context. Check: correct files present per vendor, rules format (.md vs .mdc vs .instructions.md), @-import workaround for Claude (redundant for Copilot).

## Report Format

Produce a table per vendor showing readiness:

```
Claude Code:  ✓ ready | issues: [list]
Cursor:       ✓ ready | issues: [list]
Codex:        ✓ ready | issues: [list]
Copilot CLI:  ✓ ready | issues: [list]
```

Then a prioritized issue list:

```
HIGH  [artifact] description — affects: Claude/Cursor/Codex/Copilot
MED   [artifact] description — affects: Cursor
LOW   [artifact] description — affects: all
```

## Usage

Invoke directly on a plugin root:
- "Audit plugins/vendor-harness for cross-vendor readiness"
- "Is gitflow ready to ship to Codex?"
- "Will this marketplace install in Copilot CLI?"

harness-advisor will route here when a user asks about overall plugin compatibility rather than a specific artifact problem.
