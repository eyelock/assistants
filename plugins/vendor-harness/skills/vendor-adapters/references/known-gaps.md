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
| HIGH | Copilot CLI rejects the `git-subdir` marketplace source type — and rejects the **whole** index, not just that entry, so one such row makes every plugin in the marketplace uninstallable from Copilot. Same fail-whole-file behaviour for a non-kebab-case plugin name. | Copilot CLI, Claude Code | MITIGATED — VERIFIED (2026-08-24; reproduced on Copilot CLI v1.0.80: a probe `git-subdir` entry yielded `Failed to add marketplace: Error: Invalid marketplace.json: plugins.8.source: Invalid input`, exit 1, zero plugins registered; removing that one entry made the same file load all 8. With `.github/plugin/marketplace.json` present, the broken Claude index was never parsed. upstream anthropics/claude-plugins-official#1205 and #585 remain OPEN. eyelock/assistants now publishes a Copilot-safe `.github/plugin/marketplace.json` alongside `.claude-plugin/marketplace.json`, kept in version-sync and drift-gated by `scripts/sync-manifests.mjs`) |
| HIGH | ynh has no Copilot CLI adapter — no `plugin.json`, marketplace index, hook config, MCP config, agents, or instruction files are generated for Copilot | Copilot CLI | OPEN (2026-08-24; Copilot partially works today only because it falls back to reading `.claude-plugin/plugin.json` and `.claude/skills`) |
| HIGH | Copilot custom agents require the `agents/<name>.agent.md` double extension; a bare `agents/<name>.md` exported for Claude/Cursor is silently ignored | Copilot CLI | WITHDRAWN — NOT A GAP (2026-08-24; filed from docs, disproved against Copilot CLI v1.0.80. A probe plugin with both `plain-style.md` and `suffixed-style.agent.md` registered *both*, and the bare-`.md` agent ran. No renaming needed on export) |
| MED | Copilot hook config requires a top-level `"version": 1` and uses two-level nesting (event → `[hook]`); Claude/Codex three-level `{matcher, hooks: []}` files do not bind | Copilot CLI | OPEN (2026-08-24; Copilot's PascalCase event aliases ease but do not remove the shape difference) |
| MED | Repo marketplace `ynh` entry used `{"source": "github", "url": "eyelock/ynh"}` — the `github` discriminator requires `repo`, and `url` belongs to the `url` type. Malformed for Claude Code and Copilot CLI alike. | Claude Code, Copilot CLI | RESOLVED (2026-08-24; corrected to `repo` in `.claude-plugin/` and `.cursor-plugin/` indexes. The ynh plugin lives at the root of eyelock/ynh, so no `path` is needed) |
| MED | Copilot MCP examples use `"type": "local"`, which Claude Code and Codex do not recognise; `"type": "stdio"` is the portable spelling | Copilot CLI | OPEN (2026-08-24; documentation-level guidance recorded in references/copilot.md) |
| LOW | Copilot `commands` manifest field exists but the command file format is undocumented — cannot be validated or generated | Copilot CLI | OPEN (2026-08-24; prefer skills) |
| LOW | Copilot has no `--plugin-dir` equivalent; plugin components are cached at install time so every edit needs `copilot plugin install ./path` again | Copilot CLI | WITHDRAWN — NOT A GAP (2026-08-24; filed from docs, disproved against v1.0.80. `--plugin-dir <directory>` exists and is repeatable, and reloads from the directory each run. It is absent from the published web docs but present in `copilot --help`) |
| LOW | Copilot hook timeouts fail **open** on `preToolUse`, unlike non-zero exits which fail closed — a slow security hook silently permits the tool call | Copilot CLI | OPEN (2026-08-24; upstream behaviour, mitigate with tight `timeoutSec`) |
| MED | Published Copilot command reference documents `copilot plugins list` (plural) with `--kind`/`--scope`/`--json`; v1.0.80 answers "The plugins command is not available." Real commands are `copilot plugin list` (no flags) and `copilot skill list` | Copilot CLI | OPEN (2026-08-24; upstream docs bug — worth filing at github/copilot-cli) |
| HIGH | Subagent `skills:` frontmatter is Claude-only and silently inert on Cursor, Codex, and Copilot CLI — the agent runs without its knowledge base and answers from the base model. Observed producing a confidently wrong vendor answer from this plugin's own `harness-advisor` on Copilot CLI v1.0.80 | Cursor, Codex, Copilot CLI | RESOLVED (2026-08-24; all four vendor-harness agents now name their skills as an explicit instruction in the prompt body and keep the frontmatter key. Re-verified via `--plugin-dir`: the agent loads `vendor-adapters` and answers correctly) |
| LOW | Claude model aliases (`model: sonnet`) do not resolve on Copilot CLI — warns and falls back to `auto` | Copilot CLI | OPEN (2026-08-24; non-fatal. No single value satisfies both vendors, so the alias is kept and the warning accepted) |
| LOW | Direct plugin installs (`owner/repo`, URLs, local paths) warn they are deprecated in favour of `plugin@marketplace`, but the docs still recommend `copilot plugin install ./my-plugin` for local testing | Copilot CLI | OPEN (2026-08-24; use `--plugin-dir` to iterate, a registered marketplace to install) |

All Claude Code / Cursor / Codex gaps tracked as of 2026-08-19 are resolved. The Copilot CLI
rows were opened on 2026-08-24 when Copilot was added as a fourth vendor, then checked against
Copilot CLI v1.0.80 directly. Outcome: the malformed `ynh` source is fixed; the marketplace
incompatibility is reproduced and mitigated by the two-index layout (the upstream schema
divergence itself stays open); and **two rows were withdrawn as wrong** — the `.agent.md`
requirement and the missing `--plugin-dir` were both filed from documentation and disproved by
the binary.

Lesson worth keeping: Copilot's published docs and its shipped CLI disagree in both directions
— the docs describe a `copilot plugins list` that does not exist, and omit a `--plugin-dir`
that does. Verify Copilot claims against `copilot <cmd> --help` and a probe plugin before
filing, the same way the Codex rows had to be verified against ynh's code rather than its docs.
The remaining rows have not been verified against ynh's `develop` yet.

Note: the Codex HIGH/MED items above were found already fixed in ynh's codebase when the fix
agent investigated — our reference docs had drifted stale relative to ynh's actual code, not
the other way around. Re-verify reference docs against `develop` periodically, not just
against vendor docs, to avoid re-filing already-fixed gaps. Do this for the Copilot rows
before filing anything upstream.
