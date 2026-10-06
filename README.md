# assistants

**This repository is not production software.** It is a reference collection of sample plugins, skills, and personas for exploring how [Agent Skills](https://agentskills.io/specification), [Claude Code plugins](https://code.claude.com/docs/en/plugins), [Cursor plugins](https://cursor.com/docs/plugins/overview), and plugin marketplaces work together across multiple AI coding tools. Use it to learn, experiment, and as a starting point for your own configurations.

Nothing here is guaranteed to be complete, stable, or suitable for any particular use. Skills and plugins may contain placeholder logic, opinionated patterns, or personal workflow assumptions.

## What This Repository Demonstrates

- **Cross-vendor plugins** — Each plugin carries `.agents/harness/plugin.json`, `.claude-plugin/plugin.json`, and `.cursor-plugin/plugin.json` manifests, making it usable from Claude Code, Cursor, and YNH
- **Portable skills** — Skills follow the [agentskills.io specification](https://agentskills.io/specification), the open standard adopted by Claude Code, Cursor, Codex, GitHub Copilot, and others
- **Quad marketplace** — The repo serves as a Claude Code, Cursor, YNH, and GitHub Copilot CLI marketplace from the same GitHub repository
- **Vendor-neutral instructions** — `AGENTS.md` files provide project context for Codex and Cursor alongside `CLAUDE.md` for Claude Code
- **Persona composition** — How ynh personas reference and compose skills from shared libraries (`ynh/`)

## Repository Structure

```
assistants/
├── .claude-plugin/
│   └── marketplace.json          # Claude Code marketplace index
├── .cursor-plugin/
│   └── marketplace.json          # Cursor marketplace index
├── .github/plugin/
│   └── marketplace.json          # GitHub Copilot CLI marketplace index
├── .agents/harness/
│   └── marketplace.json          # YNH marketplace index
├── AGENTS.md                     # Codex/Cursor project instructions
├── plugins/
│   ├── gitflow/                  # Gitflow workflow plugin (6 skills, 1 agent)
│   │   ├── .claude-plugin/plugin.json
│   │   ├── .cursor-plugin/plugin.json
│   │   └── .agents/harness/plugin.json
│   ├── media-management/         # Music processing plugin (7 skills, 2 agents, hooks)
│   │   ├── .claude-plugin/plugin.json
│   │   ├── .cursor-plugin/plugin.json
│   │   └── .agents/harness/plugin.json
│   └── vendor-harness/           # Vendor harness lifecycle plugin (11 skills, 4 agents)
│       ├── .claude-plugin/plugin.json
│       ├── .cursor-plugin/plugin.json
│       └── .agents/harness/plugin.json
├── skills/
│   ├── dev/                      # Development workflow plugin (9 skills)
│   │   ├── .claude-plugin/plugin.json
│   │   ├── .cursor-plugin/plugin.json
│   │   └── .agents/harness/plugin.json
│   ├── tech/                     # Language-specific plugin (4 skills)
│   │   ├── .claude-plugin/plugin.json
│   │   ├── .cursor-plugin/plugin.json
│   │   └── .agents/harness/plugin.json
│   ├── infra/                    # Infrastructure plugin (2 skills)
│   │   ├── .claude-plugin/plugin.json
│   │   ├── .cursor-plugin/plugin.json
│   │   └── .agents/harness/plugin.json
│   └── pause/                    # Conversational alignment plugin (2 skills)
│       ├── .claude-plugin/plugin.json
│       ├── .cursor-plugin/plugin.json
│       └── .agents/harness/plugin.json
└── ynh/                          # Personas (compose skills via includes)
    ├── david/
    ├── planner/
    ├── tester/
    ├── researcher/
    ├── ynh-dev/
    └── termq-dev/
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

### GitHub Copilot CLI

Install a plugin straight from this repo — Copilot resolves the `.claude-plugin/plugin.json`
manifest without any Copilot-specific file:

```bash
copilot plugin install eyelock/assistants:plugins/vendor-harness
```

Or copy skills directly (Copilot reads `~/.agents/skills` and `~/.copilot/skills`):

```bash
cp -r skills/dev/skills/dev-project ~/.copilot/skills/
```

Or add the whole marketplace:

```bash
copilot plugin marketplace add eyelock/assistants
```

This resolves `.github/plugin/marketplace.json`, a Copilot-safe mirror of the Claude index.
It exists because Copilot rejects the `git-subdir`, `npm`, `archive`, and `command` source types
Claude allows — and rejects the *whole* index over one unsupported entry, not just that row.
See `plugins/vendor-harness/skills/vendor-adapters/references/copilot.md`.

## Marketplace Plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| `gitflow` | 6 | Gitflow branching, conventional commits, quality gate, tag-driven release, push/PR workflow |
| `media-management` | 7 | Process downloaded music purchases: extract, tag, import to Apple Music, stage to NAS |
| `vendor-harness` | 11 | Lifecycle management for LLM vendor harness artifacts across Claude Code, Cursor, Codex, and GitHub Copilot CLI |
| `dev-skills` | 9 | Project setup, code quality, review, debugging, backend, UI, security, and skill authoring |
| `tech-skills` | 4 | Go, Java, Swift, and SwiftUI development workflows |
| `infra-skills` | 2 | GitHub repository setup, Terraform backend provisioning |
| `pause-skills` | 2 | Guided elicitation and context checkpoints for alignment |

## Cross-Vendor Compatibility

| Layer | Claude Code | Cursor | Codex | GitHub Copilot CLI |
|-------|-------------|--------|-------|--------------------|
| **Skills (SKILL.md)** | Native | Native | Native | Native |
| **Plugin manifest** | `.claude-plugin/plugin.json` | `.cursor-plugin/plugin.json` | `.codex-plugin/plugin.json` | `plugin.json` (falls back to `.claude-plugin/plugin.json`) |
| **YNH manifest** | `.agents/harness/plugin.json` | `.agents/harness/plugin.json` | `.agents/harness/plugin.json` | not generated |
| **Marketplace** | `.claude-plugin/marketplace.json` | `.cursor-plugin/marketplace.json` | `.agents/plugins/marketplace.json` | `.github/plugin/marketplace.json` |
| **Instructions** | `CLAUDE.md` (via `@AGENTS.md`) | `AGENTS.md`, `.cursor/rules/*.mdc` | `AGENTS.md` | `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` |
| **MCP servers** | `.mcp.json` | `mcp.json` (no dot) | `.mcp.json` | `.mcp.json` or `.github/mcp.json` |
| **Custom repos** | Any user | Teams/Enterprise | Manual install | Any user |

## Specifications

| Specification | Purpose |
|---------------|---------|
| [Agent Skills](https://agentskills.io/specification) | Vendor-neutral skill format (SKILL.md frontmatter, directory structure) |
| [Claude Code Plugins](https://code.claude.com/docs/en/plugins) | Plugin packaging for Claude Code |
| [Claude Code Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) | Marketplace distribution for Claude Code |
| [Cursor Plugins](https://cursor.com/docs/plugins/overview) | Plugin packaging for Cursor |
| [Copilot CLI Plugins](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference) | Plugin and marketplace packaging for GitHub Copilot CLI |
| [Agent Plugins 1.0](https://github.com/agentplugins/agent-plugins-spec) | Open Plugin Spec — the cross-vendor plugin standard behind Copilot's format |

## License

MIT
