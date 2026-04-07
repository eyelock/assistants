# assistants

**This repository is not production software.** It is a reference collection of sample plugins, skills, and personas for exploring how [Agent Skills](https://agentskills.io/specification), [Claude Code plugins](https://code.claude.com/docs/en/plugins), [Cursor plugins](https://cursor.com/docs/plugins/overview), and plugin marketplaces work together across multiple AI coding tools. Use it to learn, experiment, and as a starting point for your own configurations.

Nothing here is guaranteed to be complete, stable, or suitable for any particular use. Skills and plugins may contain placeholder logic, opinionated patterns, or personal workflow assumptions.

## What This Repository Demonstrates

- **Cross-vendor plugins** — Each plugin carries a `harness.json` manifest and a `.cursor-plugin/` manifest, making it usable from either tool's marketplace
- **Portable skills** — Skills follow the [agentskills.io specification](https://agentskills.io/specification), the open standard adopted by Claude Code, Cursor, Codex, GitHub Copilot, and others
- **Dual marketplace** — The repo serves as both a Claude Code marketplace and a Cursor team marketplace from the same GitHub repository
- **Vendor-neutral instructions** — `AGENTS.md` files provide project context for Codex and Cursor alongside `CLAUDE.md` for Claude Code
- **Persona composition** — How ynh personas reference and compose skills from shared libraries (`ynh/`)

## Repository Structure

```
assistants/
├── .claude-plugin/
│   └── marketplace.json          # Claude Code marketplace index
├── .cursor-plugin/
│   └── marketplace.json          # Cursor marketplace index
├── AGENTS.md                     # Codex/Cursor project instructions
├── plugins/
│   └── media-management/         # Self-contained plugin (skills, agents, hooks, tests)
│       ├── harness.json
│       ├── .cursor-plugin/plugin.json
│       ├── .claude/CLAUDE.md     # Claude Code instructions
│       └── AGENTS.md             # Codex/Cursor instructions
├── skills/
│   ├── dev/                      # Development workflow plugin (7 skills)
│   │   ├── harness.json
│   │   ├── .cursor-plugin/plugin.json
│   │   └── skills/
│   │       ├── dev-project/
│   │       ├── dev-quality/
│   │       ├── dev-review/
│   │       ├── dev-backend/
│   │       ├── dev-ui/
│   │       ├── dev-debug/
│   │       └── dev-security/
│   ├── tech/                     # Language-specific plugin (2 skills)
│   │   ├── harness.json
│   │   ├── .cursor-plugin/plugin.json
│   │   └── skills/
│   │       ├── go-lang/
│   │       └── java-lang/
│   ├── infra/                    # Infrastructure plugin (2 skills)
│   │   ├── harness.json
│   │   ├── .cursor-plugin/plugin.json
│   │   └── skills/
│   │       ├── gh-os-repo/
│   │       └── terraform-backend-aws/
│   └── pause/                    # Conversational alignment plugin (2 skills)
│       ├── harness.json
│       ├── .cursor-plugin/plugin.json
│       └── skills/
│           ├── help-me-answer/
│           └── take-a-moment/
└── ynh/                          # Personas (compose skills via includes)
    ├── david/
    ├── planner/
    ├── tester/
    └── researcher/
```

## Using the Marketplace

### Claude Code

```
/plugin marketplace add eyelock/assistants
/plugin install dev-skills@eyelock-assistants
```

Test locally:
```bash
claude --plugin-dir ./skills/dev
```

### Cursor (Teams/Enterprise)

Import this repo as a team marketplace via Dashboard > Settings > Plugins, then team members install from the plugin manager.

Individual users can test locally by copying a plugin to `~/.cursor/plugins/local/`.

### Codex

Copy skills directly:
```bash
cp -r skills/dev/skills/dev-project ~/.agents/skills/
```

Or install via the built-in skill installer:
```
$skill-installer dev-project
```

## Marketplace Plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| `media-management` | 7 | Process downloaded music purchases: extract, tag, import to Apple Music, stage to NAS |
| `dev-skills` | 7 | Project setup, code quality, review, debugging, backend, UI, and security patterns |
| `tech-skills` | 2 | Go and Java development workflows |
| `infra-skills` | 2 | GitHub repository setup, Terraform backend provisioning |
| `pause-skills` | 2 | Guided elicitation and context checkpoints for alignment |

## Cross-Vendor Compatibility

| Layer | Claude Code | Cursor | Codex |
|-------|-------------|--------|-------|
| **Skills (SKILL.md)** | Native | Native | Native |
| **Plugin manifest** | `harness.json` | `.cursor-plugin/plugin.json` | N/A |
| **Marketplace** | `.claude-plugin/marketplace.json` | `.cursor-plugin/marketplace.json` | N/A |
| **Instructions** | `.claude/CLAUDE.md` | `AGENTS.md`, `.cursor/rules/` | `AGENTS.md` |
| **MCP servers** | `.mcp.json` | `.mcp.json` | `config.toml` |
| **Custom repos** | Any user | Teams/Enterprise | Manual install |

## Specifications

| Specification | Purpose |
|---------------|---------|
| [Agent Skills](https://agentskills.io/specification) | Vendor-neutral skill format (SKILL.md frontmatter, directory structure) |
| [Claude Code Plugins](https://code.claude.com/docs/en/plugins) | Plugin packaging for Claude Code |
| [Claude Code Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) | Marketplace distribution for Claude Code |
| [Cursor Plugins](https://cursor.com/docs/plugins/overview) | Plugin packaging for Cursor |

## License

MIT
