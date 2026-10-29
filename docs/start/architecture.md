# Architecture

This repo is a collection of agent skills, plugins, harnesses and marketplace indexes. This page
explains how the pieces fit together and why they are split the way they are. For what each
feature is, see
[Agentic features](agentic-features.md). For terms, see the [Glossary](glossary.md).

## The pieces

```
marketplaces        .claude-plugin/  .cursor-plugin/  .github/plugin/  .agents/harness/
  |  list
  v
plugins             plugins/<name>  skills/<domain>      one directory, manifests per vendor
  |  contain
  v
skills              <plugin>/skills/<skill>/SKILL.md     knowledge and procedure, vendor neutral
agents              <plugin>/agents/<name>.md            subagents (gitflow, media-management, vendor-harness)
hooks               <plugin>/hooks/hooks.json            scripts the vendor runs on events
MCP servers         <plugin>/.mcp.json  or  mcp_servers  tools a model can call

harnesses           ynh/<name>/.agents/harness/plugin.json
  |  include (and pick) skills; declare MCP servers, profiles, focuses, hooks, sensors
  v
a session           what a vendor tool such as Claude Code runs
```

Read it from the bottom. A **session** is a vendor tool running a model. What the model knows and
can do in that session comes from **skills** (what to do and how), **MCP servers** (tools to call),
**hooks** (checks the vendor runs around the model) and **agents** (helpers with a narrower job).
**Plugins** package those so a vendor can install them. **Harnesses** are a second kind of package,
written for ynh: they compose skills from plugins, add servers, and name ready-made variants and
prompts. **Marketplaces** are index files that tell a vendor where the plugins are.

## The kinds of package in this repo

**Domain plugins** hold skills for one area. They are the reusable layer.

| Domain | Where | What it holds |
|---|---|---|
| Development workflow | `skills/dev`, `plugins/gitflow` | project setup, quality, review, debugging, security; Gitflow, commits, release |
| Language | `skills/tech` | Go, Java, Swift, SwiftUI |
| Infrastructure | `skills/infra` | GitHub repo setup, Terraform backend on AWS |
| Voice | `skills/voice` | writing voice and reply styles |
| Pause | `skills/pause` | guided questions and context checkpoints |
| Triage | `skills/triage` | platform-free questions about what needs you |
| Platforms | `skills/platforms` | how to work well in GitHub, Slack, Gmail, Calendar, Drive, iMessage |
| Vendor harness | `plugins/vendor-harness` | skills and agents for keeping vendor artifacts current |
| Media | `plugins/media-management` | music processing, with hooks and an MCP server |
| Wheelhouse | `plugins/wheelhouse` | building and running a team of named agent seats |

**Persona harnesses** (`ynh/david`, `planner`, `tester`, `researcher`, `ynh-dev`, `termq-dev`)
compose skills. `ynh/david` picks skills from `dev`, `tech`, `infra` and `pause`;
`ynh/termq-dev` picks from `gitflow`, `dev` and `tech`, and adds profiles and focuses.

**Platform harnesses** (`ynh/github`, `gmail`, `google-calendar`, `google-drive`, `imessage`,
`apple-calendar`, `slack`) add one MCP server to a set of skills and are read only.

## Why they are split

- **A skill is vendor neutral.** It follows the [agentskills.io](https://agentskills.io/specification)
  format, which Claude Code, Cursor, Codex and Copilot CLI all read, so the same file serves all four.
- **A plugin is the unit a vendor installs.** Each vendor wants its own manifest, so a plugin
  directory carries `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json` and
  `.agents/harness/plugin.json` side by side. The skills underneath are shared. See
  [Vendors](../harnesses/vendors.md) for how the vendors differ.
- **A harness is the unit you review.** It is a small file that says which skills, which servers
  and which checks a session gets. The risky part (a server, a credential, a hook) sits in
  one file a person can read, while the judgement sits in skills any harness can reuse.
- **Marketplaces are indexes, not copies.** Four index files point at the same directories. They
  are kept in step by `pnpm sync-manifests`, and `pnpm sync-manifests:check` gates CI. The Copilot
  index is separate because Copilot rejects the whole file over one source type Claude allows.
- **Skills carry evals.** A new skill must ship `evals/` or `pnpm test` fails, so a change can be
  measured, not guessed at. See [Agentic features](agentic-features.md#evals).

## How a request reaches a skill

1. You ask the vendor tool something. The tool shows the model the name and description of each
   installed skill, taken from the `SKILL.md` frontmatter.
2. The model picks a skill whose description fits, and the tool loads the rest of `SKILL.md`.
   A skill can point at files in its own `references/` or `scripts/`, loaded only when needed.
3. The skill's instructions steer the model. If it needs a tool, it calls one from an MCP server.
4. Around each tool call, the vendor runs any hooks. A hook can allow or block the call.
5. Only a harness (not a bare plugin) adds profiles, focuses and sensors on top. A focus starts a
   session with a named prompt; a profile swaps part of the configuration; a sensor names an
   observation a loop driver can run.

The [tutorial](../harnesses/follow-a-request.md) walks a request through these steps by opening
the real files.

## Where to see each piece

| To see | Open |
|---|---|
| a plain skill plugin | `skills/dev/.claude-plugin/plugin.json` and `skills/dev/skills/dev-review/SKILL.md` |
| a plugin with a subagent | `plugins/gitflow/agents/reviewer.md` |
| a plugin with hooks and an MCP server | `plugins/media-management/hooks/hooks.json` and `plugins/media-management/.mcp.json` |
| a plugin about the vendors' formats | `plugins/vendor-harness/skills/vendor-adapters/SKILL.md` |
| a persona harness | `ynh/david/.agents/harness/plugin.json` |
| profiles and focuses with no server | `ynh/termq-dev/.agents/harness/plugin.json` |
| a harness that adds an MCP server | `ynh/github/.agents/harness/plugin.json` |
| profiles that change a server | `ynh/imessage/.agents/harness/plugin.json` |
| the marketplace indexes | `.claude-plugin/marketplace.json`, `.cursor-plugin/marketplace.json`, `.github/plugin/marketplace.json`, `.agents/harness/marketplace.json` |

## The four areas

The same pieces add up to four areas, each a different way of fitting the YN tools together:

| Area | What it shows | Built from |
|---|---|---|
| [Library](../library/README.md) | skills and plugins, installable in any vendor tool | skills, plugins, marketplaces |
| [Personas](../personas/README.md) | one agent composed for a job | a ynh harness that includes skills, with profiles and focuses |
| [Triage](../triage/README.md) | the same questions answered across every platform | thin, read-only platform harnesses over shared triage skills |
| [Wheelhouse](../wheelhouse/README.md) | a team of named agents that work together | ynh seats, a Beads work graph, ynm memory, ynf to contain them |

How a harness works in depth (hooks, the manifest, vendors and safety) is in
[Harnesses in depth](../harnesses/README.md).
