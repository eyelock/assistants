# assistants

A monorepo of plugins, shared skills, and ynh personas.

## Structure

- **`plugins/`** — Self-contained plugins (each has its own `.claude-plugin/plugin.json`)
- **`skills/`** — Shared skill libraries organized by domain
- **`ynh/`** — ynh personas that compose skills via includes

## Usage

### Install a plugin

```bash
ynh install github.com/eyelock/assistants --path plugins/media-management
```

### Install a persona

```bash
ynh install github.com/eyelock/assistants --path ynh/david
```

Personas pull in skills from `skills/` via `includes` in their `metadata.json`.

## Skills

| Domain | Skill | Description |
|--------|-------|-------------|
| `dev` | `dev-project` | Project setup and scaffolding |
| `dev` | `dev-quality` | Code quality pipeline (lint, format, test, build) |
| `dev` | `dev-review` | Structured code review workflow |
| `gh` | `gh-os-repo` | Open source repository setup and management |
| `go` | `go-dev` | Go development workflow |

## License

MIT
