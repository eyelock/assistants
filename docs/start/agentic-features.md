# Agentic features

A coding agent is a model plus a harness: everything around the model that decides what it knows,
what it can call and what is checked. This page explains each feature that makes up that harness,
why it exists, and where in this repo you can see it working. For how they combine, see
[Architecture](architecture.md). For the differences between vendors, see [Vendors](../harnesses/vendors.md).

| Feature | Answers the question | See it in this repo |
|---|---|---|
| [Agent skill](#agent-skills) | What should the model know and do? | `skills/dev/skills/dev-review/SKILL.md` |
| [MCP server](#mcp-servers) | What can the model reach? | `ynh/github/.agents/harness/plugin.json`, `plugins/media-management/.mcp.json` |
| [Plugin](#plugins) | How do I install a bundle? | `plugins/gitflow/.claude-plugin/plugin.json` |
| [Marketplace](#marketplaces) | Where do plugins come from? | `.claude-plugin/marketplace.json` |
| [Harness](#harnesses) | Which skills, servers and checks make one agent? | `ynh/david/.agents/harness/plugin.json` |
| [Profile](#profiles) | Same harness, different setting? | `ynh/imessage/.agents/harness/plugin.json` |
| [Focus](#focuses) | A repeatable job with a ready prompt? | `ynh/termq-dev/.agents/harness/plugin.json` |
| [Hook](#hooks) | What is checked around a tool call? | `plugins/media-management/hooks/hooks.json` |
| [Sensor](#sensors) | How do we observe the result? | none declared yet |

## Agent skills

**What.** A skill is a directory with a `SKILL.md` file: YAML frontmatter with a `name` and a
`description`, then Markdown instructions. It may add `scripts/`, `references/` and `assets/`.
The format is the open [agentskills.io](https://agentskills.io/specification) specification, read
natively by Claude Code, Cursor, Codex and Copilot CLI.

**Why.** A model starts every session knowing nothing about your conventions. Putting them in
the prompt every time wastes context. A skill loads in stages: only the name and description sit
in context (the catalog), the body loads when the model decides the skill fits, and files in
`references/` load only when the body points at them. That is why a description matters most: it is
the only thing the model sees when choosing.

**Here.** This repo has skills for development workflow (`skills/dev`), languages (`skills/tech`),
infrastructure (`skills/infra`), writing voice (`skills/voice`), conversational pauses
(`skills/pause`), triage (`skills/triage`), one tool per skill (`skills/platforms`), Gitflow
(`plugins/gitflow`), music processing (`plugins/media-management`) and vendor artifacts
(`plugins/vendor-harness`). Open `skills/pause/skills/take-a-moment/SKILL.md` for a short one and
`skills/platforms/skills/github/SKILL.md` for one with `references/`.

### Evals

Every new skill ships `evals/evals.json` (does the output improve?) and `evals/eval_queries.json`
(does the skill trigger on the right requests, and stay quiet on near misses?), in the
[agentskills.io format](https://agentskills.io/skill-creation/evaluating-skills). Look at
`plugins/gitflow/skills/push/evals/`. Evals are what make a skill's description something you can
test rather than guess at. They cost money to run, so CI does not run them.

## MCP servers

**What.** The Model Context Protocol is an open protocol for giving a model tools and data from
outside the session. A server is either a local process the tool starts (`stdio`, with a `command`
and `args`) or a remote URL (`streamable-http`).

**Why.** Without it, each vendor needs its own integration for each service. With it, a service
writes one server and any MCP-capable tool can use it. A skill says how to use the tools well; the
server provides them. They are separate on purpose: you can review the server's access without
reading the skill.

**Here.**

- `ynh/github` and `ynh/slack` declare remote servers by `url`. `ynh/gmail`, `google-calendar`,
  `google-drive` and `ynh/imessage` start local ones with `npx` or `uvx`, pinned to a version.
- `plugins/media-management/.mcp.json` declares a local `rekordbox-database` server for that
  plugin, in Claude's plugin format.
- Credentials come from the environment (`env_passthrough` in a harness), never from the file.

## Plugins

**What.** A plugin is a directory a vendor can install: a manifest plus any mix of skills,
agents, hooks, MCP servers and commands. Each vendor looks for its own manifest.

**Why.** A bundle is easier to install, update and remove than loose files, and a manifest gives
it a name and version.

**Here.** Every plugin directory carries manifests for several vendors over one shared set of
skills: `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json` and
`.agents/harness/plugin.json`, kept in step by `pnpm sync-manifests`. Only `plugins/vendor-harness`
also has `.codex-plugin/plugin.json`. Compare `plugins/gitflow` (skills and an agent),
`plugins/media-management` (adds hooks and an MCP server) and `skills/dev` (skills only).

## Marketplaces

**What.** A marketplace is a JSON index that lists plugins and where each one's source is, so a
vendor tool can add the whole list once and install by name.

**Why.** It lets a team or a repo be a source of plugins without a central registry.

**Here.** One repository serves four indexes: `.claude-plugin/marketplace.json`,
`.cursor-plugin/marketplace.json`, `.github/plugin/marketplace.json` (Copilot CLI) and
`.agents/harness/marketplace.json` (ynh, which lists harnesses). `pnpm sync-manifests:check` keeps
them in step. The Copilot index is separate because Copilot rejects an index over one source type
Claude allows. See [Vendors](../harnesses/vendors.md#marketplaces).

## Harnesses

**What.** A harness, in ynh's sense, is a manifest at `.agents/harness/plugin.json` that composes
an agent: it `includes` skills from Git or a path (and can `pick` a few), declares MCP servers,
and can add profiles, focuses, hooks and sensors. ynh turns it into each vendor's native format
when you run it. The wider idea, from the engineering literature ynh cites, is
**agent = model + harness**.

**Why.** The same persona should work in more than one vendor tool, and the part that grants
access should be small enough to review.

**Here.** `ynh/` holds two kinds. Persona harnesses (`david`, `planner`, `tester`, `researcher`,
`ynh-dev`, `termq-dev`) compose skills. Platform harnesses (`github`, `gmail`, `google-calendar`,
`google-drive`, `imessage`, `apple-calendar`, `slack`) add one MCP server and are read only. `ynh/david` picks
specific skills from four plugins; `ynh/termq-dev` includes the whole `plugins/gitflow`.
[Persona harnesses](../personas/harnesses.md) and [Platform harnesses](../triage/harnesses.md)
list them all.

## Profiles

**What.** A profile is a named variant of a harness's configuration. It can change `hooks`,
`mcp_servers` and `includes`. Choosing one at run time merges it over the defaults.

**Why.** One harness should serve a quick pass, a strict one, and a privacy-sensitive one without
three copies.

**Here.** `ynh/imessage` has `redacted` and `counts`, which change the server's `--privacy` flag
from `full`. `ynh/termq-dev` declares `thorough`, `quick` and `security`, empty here: they exist
so a focus can name them.

## Focuses

**What.** A focus is a named prompt, optionally tied to a profile. `--focus <name>` starts a run
with that prompt and profile.

**Why.** A recurring job ("review this", "write the changelog") should be a name, so a person, a
scheduler or CI can run it the same way each time.

**Here.** `ynh/termq-dev` has focuses `code-review`, `security-audit`, `refactor`, `pr-summary`
and `changelog`, some tied to a profile. The platform harnesses give each triage question a focus
(`waiting-on-me`, `catch-up`, `find`, and so on).

## Hooks

**What.** A hook is a command the vendor runs at a point in the session: before or after a tool
call, before a prompt, after each turn, at session start or end. A hook can block an action. Vendors name the
events differently; ynh defines six canonical events (`before_tool`, `after_tool`,
`before_prompt`, `on_stop`, `on_session_start`, `on_session_end`) and translates.

**Why.** Instructions to a model are advice; a hook is enforced by the vendor, not the model.
Use one where being wrong costs something.

**Here.** `plugins/media-management/hooks/hooks.json` binds scripts in the same folder to
Claude's `SessionStart` and `PreToolUse` events. `validate-bash-command.sh` blocks unsafe shell
commands (exit 2 with a message); `auto-approve-tools.sh` allows reads inside configured folders.
`plugins/media-management/tests/hooks/` tests them. A `before_tool` hook in a ynh harness is in
`ynh/apple-calendar`; see [Safety](../harnesses/safety.md).

## Sensors

**What.** A sensor is a declared observation of the result: a build, a test run, a linter, a scan,
named in the harness with a category and where its output lands. ynh declares sensors; a loop
driver (CI or an orchestrator) runs them between turns and feeds the result back.

**Why.** Guides (skills, rules) steer before the model acts; sensors check after. A loop needs
both.

**Here.** No harness in this repo declares a sensor yet. The repo's nearest equivalents are checks
that run on the repo itself: `pnpm test`, `pnpm lint` and `pnpm check`, the SkillSpector scan in
CI, and the evals. To see the feature, read ynh's own `docs/sensors.md` in the ynh repository.

## Read next

- [Follow a request](../harnesses/follow-a-request.md): open the real files in order.
- [Architecture](architecture.md): how the pieces layer.
- [Safety](../harnesses/safety.md): how risk is handled.
- [Glossary](glossary.md).
