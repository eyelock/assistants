# Vendor Harness — Known Gaps

| Priority | Description | Vendor | Status |
|----------|-------------|--------|--------|
| HIGH | Copilot CLI rejects the `git-subdir` marketplace source type, and rejects the **whole** index, not just that entry | Copilot CLI | OPEN (2026-08-24; reproduced on v1.0.80) |
| HIGH | ynh has no Copilot CLI adapter: no plugin.json, hook config, MCP config, agents, or instruction files are generated for Copilot | Copilot CLI | OPEN (2026-08-24) |
| MED | Copilot hook config requires a top-level `"version": 1` and uses two-level nesting; Claude/Codex three-level files do not bind | Copilot CLI | OPEN (2026-08-24) |
| MED | Copilot MCP examples use `"type": "local"`, which Claude Code and Codex do not recognize; `"type": "stdio"` is the portable spelling | Copilot CLI | OPEN (2026-08-24) |
| MED | GitHub's documented custom-agent tool aliases (`web`, `read`, `execute`) do not work in `tools:` frontmatter; only raw tool names (`web_fetch`, `view`, `bash`) grant the capability | Copilot CLI | OPEN (2026-08-25; upstream docs bug) |
| LOW | Claude model aliases (`model: sonnet`) do not resolve on Copilot CLI; it warns and falls back to `auto` | Copilot CLI | OPEN (2026-08-24; non-fatal) |
| LOW | Copilot `commands` manifest field exists but the command file format is undocumented | Copilot CLI | OPEN (2026-08-24; prefer skills) |
