# assistants

This is a reference repository of sample plugins, skills, and personas. It is not production software.

## Repository Structure

- `plugins/` — Self-contained plugins with vendor-specific manifests (`.claude-plugin/`, `.cursor-plugin/`)
- `skills/` — Shared skill plugins organized by domain, each with its own plugin manifests
- `ynh/` — Personas that compose skills from the shared library via includes
- `.claude-plugin/marketplace.json` — Claude Code marketplace index
- `.cursor-plugin/marketplace.json` — Cursor marketplace index

## Skills

All skills follow the [agentskills.io specification](https://agentskills.io/specification). Each skill is a directory containing a `SKILL.md` file with YAML frontmatter (`name`, `description`) followed by Markdown instructions. Skills may include `scripts/`, `references/`, and `assets/` subdirectories.

Skills live under `skills/<domain>/skills/<skill-name>/SKILL.md`.

## Conventions

- Scripts output JSON to stdout, diagnostics to stderr
- Scripts accept `--help` for usage information
- Exit codes: 0 success, 1 bad args, 2 file not found, 3 tool error
- Scripts are idempotent and safe to re-run
- No interactive prompts — all input via arguments
- macOS compatible — no bash 4+ features, no GNU-only flags

## Working with this repo

- Do not modify skills content without understanding the agentskills.io spec
- Plugin manifests exist in both `.claude-plugin/` and `.cursor-plugin/` — keep them in sync
- Marketplace JSON files exist in both directories — keep them in sync
- The `ynh/` personas use a separate metadata format (`metadata.json`) for skill composition
