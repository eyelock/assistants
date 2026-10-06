---
name: vendor-adapters
description: Master cross-vendor reference for Claude Code, Cursor, Codex and Copilot CLI harness formats — support matrix, manifest and marketplace paths, marketplace source types, documentation URLs, and the verified known-gaps table (including where a vendor's own docs are wrong). Use when comparing vendors, porting a plugin from one vendor to another, or keeping the references current.
---

This is the single source of truth for how harness artifacts map across Claude Code, Cursor, Codex, and GitHub Copilot CLI. Use it when comparing vendor behavior, checking format compatibility, or running a vendor sync update.

## Vendor Documentation URLs

### Claude Code (Anthropic)

| Area | URL |
|------|-----|
| CLI Reference | https://code.claude.com/docs/en/cli-reference |
| Plugins Overview | https://code.claude.com/docs/en/plugins |
| Plugins Reference | https://code.claude.com/docs/en/plugins-reference |
| Plugin Marketplaces | https://code.claude.com/docs/en/plugin-marketplaces |
| Hooks Guide | https://code.claude.com/docs/en/hooks-guide |
| MCP Servers | https://code.claude.com/docs/en/mcp |
| Settings Reference | https://code.claude.com/docs/en/settings |
| Subagents | https://code.claude.com/docs/en/sub-agents |
| Official Plugins Repo | https://github.com/anthropics/claude-plugins-official |

### OpenAI Codex

| Area | URL |
|------|-----|
| Plugins Overview | https://developers.openai.com/codex/plugins |
| Plugin Build Guide | https://developers.openai.com/codex/plugins/build |
| Hooks | https://developers.openai.com/codex/hooks |
| CLI Reference | https://developers.openai.com/codex |
| GitHub Repo | https://github.com/openai/codex |
| Hook Schemas | https://github.com/openai/codex/tree/main/codex-rs/hooks/schema/generated |

### Cursor

| Area | URL |
|------|-----|
| Plugin Template | https://github.com/cursor/plugin-template |
| Official Plugins Repo | https://github.com/cursor/plugins |
| Marketplace | https://cursor.com/marketplace |
| Plugins Reference | https://cursor.com/docs/reference/plugins |
| MCP Servers | https://cursor.com/docs/context/mcp |
| Rules (.mdc) | https://cursor.com/docs/context/rules |
| Hooks | https://cursor.com/docs/hooks |
| Subagents | https://cursor.com/docs/subagents |
| CLI | https://cursor.com/cli |
| Forum: .agents/ support | https://forum.cursor.com/t/support-for-agent-folder-compatibility/154167 |

### GitHub Copilot CLI

| Area | URL |
|------|-----|
| Product Page | https://github.com/features/copilot/cli |
| About CLI Plugins | https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-plugins |
| Creating a Plugin | https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating |
| Creating a Marketplace | https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace |
| Plugin Reference | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference |
| Command Reference | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference |
| Programmatic Reference | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference |
| Config Directory Reference | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference |
| Hooks Reference | https://docs.github.com/en/copilot/reference/hooks-reference |
| Custom Agents Configuration | https://docs.github.com/en/copilot/reference/custom-agents-configuration |
| Agent Skills | https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills |
| Custom Instructions | https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions |
| MCP Servers | https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers |
| Issue Tracker | https://github.com/github/copilot-cli |

### Cross-Vendor Standards

| Area | URL |
|------|-----|
| Agent Skills | https://agentskills.io |
| AGENTS.md Spec | https://github.com/agentsmd/agents.md |
| .agents/ Folder Spec | https://github.com/agentsfolder/spec |
| MCP Spec | https://modelcontextprotocol.io/specification/2025-03-26 |
| Agent Plugins 1.0 (Open Plugin Spec) | https://github.com/agentplugins/agent-plugins-spec |

## Vendor Support Matrix

Quick-lookup: what each vendor supports. For format details see references/.

| Artifact | Claude Code | Cursor | Codex | Copilot CLI |
|----------|-------------|--------|-------|-------------|
| Skills | ✓ full | ✓ full | ✓ full | ✓ full (also reads `.claude/skills`) |
| SubAgents | ✓ full | ✓ full (`name`+`description`) | ✗ not in plugins | ✓ full (`agents/*.md` or `*.agent.md`) |
| MCP | ✓ stdio + HTTP | ✓ stdio + SSE + OAuth | ✓ stdio only | ✓ stdio/local + HTTP + SSE |
| Hooks | ✓ ~30 events, 5 types | ✓ 21 events, flat format | ✓ 11 events, command only | ✓ 14 events, 3 types, `version: 1` |
| Startup Context | ✓ CLAUDE.md + rules/ | ✓ .cursor/rules/*.mdc | ✓ AGENTS.md only | ✓ AGENTS.md + CLAUDE.md + copilot-instructions.md |
| Rules in plugins | ✓ .claude/rules/*.md | ✓ .mdc with frontmatter | ✗ not supported | ~ `*.instructions.md` with `applyTo` |
| Commands | ✓ legacy (prefer skills) | ✓ commands/*.md | ✗ not supported | ~ manifest field only, format undocumented |
| LSP | ✓ .lsp.json | ✗ | ✗ | ✓ lsp.json / .github/lsp.json |

## Manifest and Marketplace Path Resolution

Copilot CLI reads Claude Code's manifest paths as a fallback, which is why a Claude plugin
often installs into Copilot unchanged.

| Vendor | Plugin manifest | Marketplace index |
|--------|-----------------|-------------------|
| Claude Code | `.claude-plugin/plugin.json` | `.claude-plugin/marketplace.json` |
| Cursor | `.cursor-plugin/plugin.json` | `.cursor-plugin/marketplace.json` |
| Codex | `.codex-plugin/plugin.json` | `.agents/plugins/marketplace.json` |
| Copilot CLI | `.plugin/` → `plugin.json` → `.github/plugin/` → `.claude-plugin/` | `marketplace.json` → `.plugin/` → `.github/plugin/` → `.claude-plugin/` |

## Marketplace Source Types — the Claude ↔ Copilot trap

Copilot CLI will read `.claude-plugin/marketplace.json`, but the two vendors do not accept
the same `source` discriminators. An unrecognised type fails **the whole index**, not just
that entry, so one bad row makes every plugin in the marketplace uninstallable from Copilot.

| `source` type | Claude Code | Copilot CLI (tested, v1.0.80) |
|---------------|-------------|-------------------------------|
| relative path string | ✓ | ✓ |
| `github` object | ✓ (no `path`) | ✓ (supports `path`) |
| `url` object | ✓ (no `path`) | ✓ |
| `git-subdir` object | ✓ (only Claude type with `path`) | ✗ **rejected — fails whole file** |
| `npm` object | ✓ | ✗ **rejected** |
| `archive` object | ✓ | ✗ **rejected** |
| `command` object | ✓ | ✗ **rejected** |

Copilot accepts exactly three: relative path, `github`, `url`.

Plugin names must be kebab-case for Copilot; a dot (e.g. `wordpress.com`) also fails the whole
index unless the plugin opts into Open Plugin Spec via `$schema`.

Portable choice: relative paths. For a git subdirectory, Copilot wants
`{"source": "github", "repo": "o/r", "path": "sub/dir"}` (or the `OWNER/REPO:PATH` install
string) while Claude wants `{"source": "git-subdir", "url": …, "path": …}` — no single row
satisfies both, so publish a Copilot-safe `.github/plugin/marketplace.json` alongside the
Claude one.

See references/copilot.md for the full detail and the upstream issues.

## Format Mapping Tables

(See references/ directory for full format details — anthropic.md, cursor.md, codex.md, copilot.md)

## Known Gaps

All gaps live in one table: references/known-gaps.md. Each gap entry:
- Priority: HIGH / MED / LOW
- Description: what's wrong or missing
- Vendor: which vendor
- Status: OPEN / RESOLVED / MITIGATED / WITHDRAWN (with a dated note)

## Update Workflow

When vendor documentation changes:

1. Use fetch-vendor-docs skill to retrieve current docs from URLs above
2. Compare against stored references in this skill's references/ directory
3. Identify: what changed, what's new, what was removed
4. Update affected reference files
5. Use flag-vendor-gaps skill to update gap table
