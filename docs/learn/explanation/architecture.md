# Architecture

This repo is a collection of agent skills, plugins, harnesses and marketplace indexes. This page
explains how the pieces fit together and why they are split the way they are. Triage, one of the
domains here, is used as a worked example near the end. For what each feature is, see
[Agentic features](agentic-features.md). For terms, see the [Glossary](../reference/glossary.md).

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

**Persona harnesses** (`ynh/david`, `planner`, `tester`, `researcher`, `ynh-dev`, `termq-dev`)
compose skills. `ynh/david` picks skills from `dev`, `tech`, `infra` and `pause`;
`ynh/termq-dev` picks from `gitflow`, `dev` and `tech`, and adds profiles and focuses.

**Platform harnesses** (`ynh/github`, `gmail`, `google-calendar`, `google-drive`, `imessage`,
`slack`) add one MCP server to a set of skills and are read only.

## Why they are split

- **A skill is vendor neutral.** It follows the [agentskills.io](https://agentskills.io/specification)
  format, which Claude Code, Cursor, Codex and Copilot CLI all read, so the same file serves all four.
- **A plugin is the unit a vendor installs.** Each vendor wants its own manifest, so a plugin
  directory carries `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json` and
  `.agents/harness/plugin.json` side by side. The skills underneath are shared. See
  [Vendors](vendors.md) for how the vendors differ.
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

The [tutorial](../tutorials/follow-a-request.md) walks a request through these steps by opening
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

## Worked example: triage

Triage is the domain where all the layers show up at once, which makes it a good example. It is
one domain among several, and no other domain depends on it.

```
ynh/github                 thin harness: includes skills/triage, picks the github platform skill,
  |                        declares one MCP server, gives each question a focus
  v
skills/platforms/skills    platform skills: where to look on one platform
skills/triage/skills       generic triage skills: what to ask, and the shape of the answer
```

**Generic triage skills** (`skills/triage`) say what to ask and how to answer, without naming a
platform: `waiting-on-me`, `waiting-on-them`, `action-now-or-soon`, `my-commitments`, `catch-up`,
`find`, and `triage-report`, which holds the shared rules and answer shape. **Platform skills**
(`skills/platforms`) say where to look: each has a `SKILL.md`, `references/tools.md` for the
server's tools, and `references/triage.md` mapping each question to those tools.

The split pays off here for three reasons:

- A new question is written once, in the triage layer, and every platform answers it the same way.
  The common list lives in `skills/triage/skills/add-triage-question/assets/questions.json`.
- A new platform is one platform skill and one thin harness. It does not touch the triage skills.
- `pnpm test` fails when a harness and the common list disagree, or when a harness picks a skill
  that does not exist.

The same shape (a generic skill, a platform skill, a thin harness) could carry another domain.
Nothing in the layering is specific to triage.

For the harness-by-harness facts, see [Harnesses](../../use/reference/harnesses.md) and
[Triage questions](../../use/reference/triage-questions.md). For how this repo keeps risk down,
see [Safety](safety.md).
