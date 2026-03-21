# assistants

**This repository is not production software.** It is a reference collection of sample plugins, skills, and personas for exploring how [Agent Skills](https://agentskills.io/specification), [Claude Code plugins](https://code.claude.com/docs/en/plugins), and [plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) work together. Use it to learn, experiment, and as a starting point for your own configurations.

Nothing here is guaranteed to be complete, stable, or suitable for any particular use. Skills and plugins may contain placeholder logic, opinionated patterns, or personal workflow assumptions.

## What This Repository Demonstrates

- **Plugin structure** — How to organize a self-contained Claude Code plugin with skills, agents, hooks, and permissions (`plugins/media-management/`)
- **Skill plugins** — How to package a shared skill library as a Claude Code plugin so it can be distributed via a marketplace (`skills/dev/`, `skills/tech/`, etc.)
- **Marketplace configuration** — How to turn a single repository into a Claude Code plugin marketplace (`.claude-plugin/marketplace.json`)
- **Agent Skills spec** — Skills follow the [agentskills.io specification](https://agentskills.io/specification), making them portable across agent systems
- **Persona composition** — How ynh personas reference and compose skills from shared libraries (`ynh/`)

## Repository Structure

```
assistants/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace index for Claude Code
├── plugins/
│   └── media-management/         # Self-contained plugin (skills, agents, hooks, tests)
├── skills/
│   ├── dev/                      # Development workflow plugin (7 skills)
│   │   ├── .claude-plugin/plugin.json
│   │   └── skills/
│   │       ├── dev-project/
│   │       ├── dev-quality/
│   │       ├── dev-review/
│   │       ├── dev-backend/
│   │       ├── dev-ui/
│   │       ├── dev-debug/
│   │       └── dev-security/
│   ├── tech/                     # Language-specific plugin (2 skills)
│   │   ├── .claude-plugin/plugin.json
│   │   └── skills/
│   │       ├── go-lang/
│   │       └── java-lang/
│   ├── infra/                    # Infrastructure plugin (2 skills)
│   │   ├── .claude-plugin/plugin.json
│   │   └── skills/
│   │       ├── gh-os-repo/
│   │       └── terraform-backend-aws/
│   └── pause/                    # Conversational alignment plugin (2 skills)
│       ├── .claude-plugin/plugin.json
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

Add this repository as a Claude Code marketplace:

```
/plugin marketplace add eyelock/assistants
```

Then install individual plugins:

```
/plugin install media-management@eyelock-assistants
/plugin install dev-skills@eyelock-assistants
/plugin install tech-skills@eyelock-assistants
/plugin install infra-skills@eyelock-assistants
/plugin install pause-skills@eyelock-assistants
```

### Testing Locally

Load any plugin directly without installing:

```bash
claude --plugin-dir ./plugins/media-management
claude --plugin-dir ./skills/dev
```

## Marketplace Plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| `media-management` | 7 | Process downloaded music purchases: extract, tag, import to Apple Music, stage to NAS |
| `dev-skills` | 7 | Project setup, code quality, review, debugging, backend, UI, and security patterns |
| `tech-skills` | 2 | Go and Java development workflows |
| `infra-skills` | 2 | GitHub repository setup, Terraform backend provisioning |
| `pause-skills` | 2 | Guided elicitation and context checkpoints for alignment |

## Specifications

This repository targets compliance with:

| Specification | Purpose |
|---------------|---------|
| [Agent Skills](https://agentskills.io/specification) | Vendor-neutral skill format (SKILL.md frontmatter, directory structure) |
| [Claude Code Plugins](https://code.claude.com/docs/en/plugins) | Plugin packaging for Claude Code (plugin.json, skills/, agents/, hooks/) |
| [Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) | Marketplace distribution (marketplace.json, plugin sources) |

## License

MIT
