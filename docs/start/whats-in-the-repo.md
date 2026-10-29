# What is in the repo

`eyelock/assistants` is a reference collection, not production software. It holds working
examples of the pieces that make an AI coding assistant useful: a library of skills and plugins,
the personas composed from it, and two advanced areas, Triage and the Wheelhouse, that fit the YN
tools together in larger ways. This page maps it and says when you would reach for each part. The facts are listed in
[Skills](../library/skills.md), [Plugins](../library/plugins.md),
[Persona harnesses](../personas/harnesses.md) and [Platform harnesses](../triage/harnesses.md).

## Three layers

- **Skills** are instructions an agent loads when a request matches. They follow the open
  agentskills.io format, so they work in Claude Code, Cursor, Codex and Copilot CLI.
- **Plugins** package skills with agents and hooks for a tool to install. `plugins/` holds the
  richer ones; `skills/` holds skill packages that are plugins too, with skills only.
- **Harnesses** (`ynh/`) are what the `ynh` tool runs: a named bundle that picks skills from the
  rest, and sometimes adds an MCP server. A persona picks skills for a kind of work. A platform
  harness also reads one service.

The same skills sit underneath all three. A persona and a plugin can both use `dev-review`.

## The domains

| Domain | Where | Reach for it when |
|---|---|---|
| Development workflow | `skills/dev` | you start a project, review, debug or want a quality pipeline |
| Gitflow | `plugins/gitflow` | you want branches, commits, PRs and releases done one consistent way |
| Languages | `skills/tech` | you write Go, Java, Swift or SwiftUI |
| Infrastructure | `skills/infra` | you set up a public GitHub repo or a Terraform backend on AWS |
| Pause | `skills/pause` | you are working out a decision, or an agent has drifted and you want to realign |
| Writing voice | `skills/voice` | you draft replies in a consistent tone for Slack, email or reviews |
| Triage | `skills/triage` | you ask what is waiting on you, or what you are waiting on, on any platform |
| Platforms | `skills/platforms` | an agent must read GitHub, Slack, Gmail, Calendar, Drive or Messages well |
| Music | `plugins/media-management` | you process purchased music or CDs into Apple Music and a NAS |
| Vendor harness | `plugins/vendor-harness` | you build skills, hooks or plugins and need them to work across tools |
| Wheelhouse | `plugins/wheelhouse` | you want a team of named agents sharing a work graph and memory |

Triage and the Wheelhouse are domains too, but each is an area of its own in these docs:
[Triage](../triage/README.md) answers a shared set of questions the same way on seven platforms,
and the [Wheelhouse](../wheelhouse/README.md) runs a team of agents. Nothing else depends on
either.

## The personas

Six personas pick skills from the domains above: `david` (broad development), `planner`,
`researcher`, `tester`, and two project personas, `termq-dev` and `ynh-dev`, which add Gitflow and
a language. Reach for a persona when you want one ready-made working mode and not a list of
skills. See [Run a persona](../personas/run-a-persona.md).

## The platform harnesses

Seven read-only harnesses answer the triage questions on one platform each. Reach for them when you
want those answers from the terminal. They need credentials, covered in
[Connect a platform](../triage/connect-a-platform.md). Why they cannot write is explained in
[Safety](../harnesses/safety.md).

## The rest of the repository

- `.claude-plugin/`, `.cursor-plugin/`, `.github/plugin/` and `.agents/harness/` each hold a
  marketplace index for one tool.
- `docs/` is this documentation; `make docs` serves it at http://localhost:3000.
- `scripts/`, `e2e-fixtures/` and each package's `evals/` check the rest: see
  [Testing and CI](../testing/README.md).

## Where to go next

New to the repository: [Install a plugin](../library/install-a-plugin.md). Want a ready persona:
[Run a persona](../personas/run-a-persona.md).
