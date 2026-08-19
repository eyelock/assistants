# Vendor Harness — Known Gaps

| Priority | Description | Vendor | Status |
|----------|-------------|--------|--------|
| HIGH | Codex plugin manifest not generated | Codex | RESOLVED (already fixed pre-2026-07-30 in eyelock/ynh#186; confirmed via eyelock/ynh#192) |
| HIGH | Codex skills export path wrong (.agents/skills/ should be skills/) | Codex | RESOLVED (already fixed pre-2026-07-30 in eyelock/ynh#186; confirmed via eyelock/ynh#193) |
| HIGH | Cursor `.cursor/rules/*.md` (no frontmatter) is silently ignored — plain .md rules never load | Cursor | RESOLVED (eyelock/ynh#196 / eyelock/ynh#201, 2026-08-19) |
| HIGH | Codex hooks are no longer experimental — enabled by default; flag renamed `codex_hooks`→`hooks` | Codex | RESOLVED (2026-08-19; reference files updated to reflect corrected default-on status) |
| MED | Codex MCP written as `.codex/config.toml` (TOML) instead of `.mcp.json` (JSON) | Codex | RESOLVED (already fixed pre-2026-07-30 in eyelock/ynh#186; confirmed via eyelock/ynh#194) |
| MED | Codex excluded from marketplace generation | Codex | RESOLVED (already fixed pre-2026-07-30 in eyelock/ynh#186; confirmed via eyelock/ynh#195) |
| MED | Cursor plugin hooks format mismatch (flat legacy vs three-level) | Cursor | RESOLVED (eyelock/ynh#197 / eyelock/ynh#203, 2026-08-19 — both paths confirmed to use the same flat format; ynh now writes both) |
| MED | Cursor plugin-format MCP path (`mcp.json`, no dot) not written at plugin root | Cursor | RESOLVED (eyelock/ynh#198 / eyelock/ynh#202, 2026-08-19 — ynh now writes both `.cursor/mcp.json` and plugin-root `mcp.json`) |
| MED | Codex hook event list understated (5 documented vs 11 actual: adds SessionEnd, SubagentStart/Stop, PermissionRequest, PreCompact/PostCompact) | Codex | RESOLVED (2026-08-19; reference files updated) |
| MED | Claude Code hook event list understated (25 documented vs ~30 actual: adds Setup, UserPromptExpansion, PostToolBatch, MessageDisplay, DirectoryAdded) and missing `mcp_tool` hook type | Claude Code | RESOLVED (2026-08-19; reference files updated) |
| LOW | SessionStart canonical event not mapped | All | RESOLVED (eyelock/ynh#199 / eyelock/ynh#204, 2026-08-19 — mapped as `on_session_start`; other Cursor-only events like `beforeShellExecution` remain unmapped, tracked separately if needed) |
| LOW | Claude Code subagent frontmatter missing `permissionMode`, `mcpServers`, `hooks` fields in reference | Claude Code | RESOLVED (2026-08-19; reference file updated) |
| LOW | Codex/Cursor doc URLs redirect (developers.openai.com→learn.chatgpt.com; docs.cursor.com→cursor.com/docs/context/*) | Codex, Cursor | RESOLVED (2026-08-19; canonical URLs updated) |
| LOW | Cursor delegation/subagent support needs further research | Cursor | RESOLVED (eyelock/ynh#200, 2026-08-19 — confirmed working via cursor.com/docs/subagents; ynh's `BuildDelegateAgent` already emits required `name`/`description` frontmatter) |

All tracked gaps as of 2026-08-19 are resolved. Note: the Codex HIGH/MED items above
were found already fixed in ynh's codebase when the fix agent investigated — our
reference docs had drifted stale relative to ynh's actual code, not the other way
around. Re-verify reference docs against `develop` periodically, not just against
vendor docs, to avoid re-filing already-fixed gaps.
