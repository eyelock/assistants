# Persona harnesses

One row per persona in `ynh/`, read from its `.agents/harness/plugin.json`. A harness is what
`ynh` installs and runs; see [Run a persona](run-a-persona.md) to use one. The other kind of
harness here, which reads one platform, is in [Platform harnesses](../triage/harnesses.md).

Personas compose skills for a kind of work. They have no MCP server and no platform to protect. They compose skills from the shared library
(`skills/` and `plugins/`) through `includes`. None sets `agent`, `env_passthrough` or
`mcp_servers`. Install one with `ynh install github.com/eyelock/assistants --path ynh/<name>`.

| Harness | Purpose | Includes | Profiles | Focuses |
|---|---|---|---|---|
| `david` | David's personal development persona | `dev-project`, `dev-quality`, `dev-review`, `dev-security`, `dev-backend`, `dev-ui`, `dev-debug`, `go-lang`, `gh-os-repo`, `terraform-backend-aws`, `help-me-answer`, `take-a-moment` | none | none |
| `planner` | Architecture and implementation planning | `dev-project`, `dev-review`, `gh-os-repo` | none | none |
| `researcher` | Research and analysis | `dev-review` | none | none |
| `tester` | Testing and quality assurance | `dev-quality`, `go-lang` | none | none |
| `termq-dev` | TermQ development, Gitflow with Swift and SwiftUI | the `gitflow` plugin, `dev-quality`, `dev-review`, `skill-creator`, `gh-cli`, `swift-lang` | `thorough`, `quick`, `security` | `code-review`, `security-audit`, `refactor`, `pr-summary`, `changelog` |
| `ynh-dev` | ynh development | the `gitflow` plugin, `golang-pro` from `github.com/Jeffallan/claude-skills`, `dev-quality`, `dev-review`, `skill-creator`, `gh-cli`, `go-lang`, the `pause` skills | `thorough`, `quick`, `security` | `code-review`, `security-hardening`, `cli-contract`, `refactor`, `changelog` |

`ynh-dev` is the only harness that includes something from outside this repository.
No persona declares `hooks` or `sensors`.
