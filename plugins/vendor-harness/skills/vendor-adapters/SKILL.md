---
name: vendor-adapters
description: Master cross-vendor reference for LLM vendor harness formats — complete format mapping tables, documentation URLs, known gaps, and the workflow for keeping references current.
---

This is the single source of truth for how harness artifacts map across Claude Code, Cursor, and Codex. Use it when comparing vendor behavior, checking format compatibility, or running a vendor sync update.

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
| MCP Servers | https://docs.cursor.com/advanced/mcp |
| Rules (.mdc) | https://docs.cursor.com/advanced/rules |
| CLI | https://cursor.com/cli |
| Forum: .agents/ support | https://forum.cursor.com/t/support-for-agent-folder-compatibility/154167 |

### Cross-Vendor Standards

| Area | URL |
|------|-----|
| Agent Skills | https://agentskills.io |
| AGENTS.md Spec | https://github.com/agentsmd/agents.md |
| .agents/ Folder Spec | https://github.com/agentsfolder/spec |
| MCP Spec | https://modelcontextprotocol.io/specification/2025-03-26 |

## Vendor Support Matrix

Quick-lookup: what each vendor supports. For format details see references/.

| Artifact | Claude Code | Cursor | Codex |
|----------|-------------|--------|-------|
| Skills | ✓ full | ✓ full | ✓ full |
| SubAgents | ✓ full | ~ partial (research needed) | ✗ not in plugins |
| MCP | ✓ stdio + HTTP | ✓ stdio + SSE + OAuth | ✓ stdio only |
| Hooks | ✓ 25 events, 4 types | ✓ 25 events, 2 formats | ~ 5 events, command only (experimental) |
| Startup Context | ✓ CLAUDE.md + rules/ | ✓ .cursor/rules/*.mdc | ✓ AGENTS.md only |
| Rules in plugins | ✓ .claude/rules/*.md | ✓ .mdc with frontmatter | ✗ not supported |
| Commands | ✓ legacy (prefer skills) | ✓ commands/*.md | ✗ not supported |

## Format Mapping Tables

(See references/ directory for full format details — anthropic.md, cursor.md, codex.md)

## Known Gaps

Track gaps in references/vendor-*.md files. Each gap entry:
- Priority: HIGH / MED / LOW
- Description: what's wrong or missing
- Vendor: which vendor
- Status: OPEN / RESOLVED (with resolution note)

## Update Workflow

When vendor documentation changes:

1. Use fetch-vendor-docs skill to retrieve current docs from URLs above
2. Compare against stored references in this skill's references/ directory
3. Identify: what changed, what's new, what was removed
4. Update affected reference files
5. Use flag-vendor-gaps skill to update gap table
