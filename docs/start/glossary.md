# Glossary

Terms used across this repo's docs, in alphabetical order. Each entry says what the term means
here and points to a file where you can see it. For the reasoning behind them, see
[Agentic features](agentic-features.md).

**agent.** A model plus a harness: the model, and everything around it that sets what it knows,
what it can call and what is checked. In a plugin, an *agent* is also a markdown file in `agents/`
that defines a subagent with a narrower job and its own tool list, such as
`plugins/gitflow/agents/reviewer.md`.

**agentskills.io.** The open specification for skills: a directory with a `SKILL.md`, YAML
frontmatter with `name` and `description`, and optional `scripts/`, `references/` and `assets/`.

**AGENTS.md.** A plain Markdown file of project instructions that Cursor, Codex and Copilot CLI
read. Claude Code reads `CLAUDE.md`, which can import it. See `AGENTS.md` at the repo root.

**barrier.** What actually stops an agent doing something. This repo's docs use it for the
mechanism behind a risk tier: a read-only server, a token's scopes, or a hook. See
[Safety](../harnesses/safety.md).

**Beads.** A work graph for agents (`bd`): beads are tasks, with who holds each and what blocks
what. The Wheelhouse keeps one in `.beads/`. See [Build a Wheelhouse](../wheelhouse/build-a-wheelhouse.md).

**catalog.** The list of skill names and descriptions a vendor tool keeps in the model's context.
The rest of a skill loads only when the model chooses it.

**eval.** A test of a skill. Output evals (`evals/evals.json`) compare results with and without
the skill; trigger evals (`evals/eval_queries.json`) check it fires on the right requests. Example:
`plugins/gitflow/skills/push/evals/`.

**focus.** A named prompt in a harness, optionally tied to a profile, started with `--focus`.
Example: `focuses` in `ynh/termq-dev/.agents/harness/plugin.json`.

**guide and sensor.** The two kinds of control in harness engineering. A guide steers before the
agent acts (skills, rules, instructions). A sensor observes after (tests, linters, scans).

**harness.** In ynh, a manifest at `.agents/harness/plugin.json` that composes an agent from
included skills, MCP servers, profiles, focuses, hooks and sensors. Example:
`ynh/david/.agents/harness/plugin.json`. See *persona harness* and *platform harness*.

**hook.** A command the vendor runs at a point in a session, such as before a tool call. A hook
that exits with code 2 blocks the action and its message goes to the model. Example:
`plugins/media-management/hooks/hooks.json`.

**include and pick.** How a harness takes skills from elsewhere. `includes` names a Git repo and
path; `pick` limits it to named skills. Example: `ynh/github/.agents/harness/plugin.json`.

**library.** One of the four areas: the skills and plugins in `skills/` and `plugins/`, installable
in any vendor tool and composed by the harnesses. See [Library](../library/README.md).

**marketplace.** A JSON index of plugins that a vendor tool can add and install from. This repo
has four: `.claude-plugin/marketplace.json`, `.cursor-plugin/marketplace.json`,
`.github/plugin/marketplace.json` and `.agents/harness/marketplace.json`.

**MCP (Model Context Protocol).** An open protocol that gives a model tools and data from outside
the session. A server is a local process (`command`, `args`) or a remote `url`.

**MCP server.** A program that offers tools over MCP. Example: the `github` entry in
`ynh/github/.agents/harness/plugin.json`.

**persona harness.** A harness that only composes skills, with no MCP server: `ynh/david`,
`planner`, `tester`, `researcher`, `ynh-dev`, `termq-dev`.

**platform harness.** A harness that adds one MCP server to a set of skills and is read only:
`ynh/github`, `gmail`, `google-calendar`, `google-drive`, `imessage`, `apple-calendar`, `slack`.

**plugin.** A directory a vendor can install: a manifest plus skills, agents, hooks, MCP servers
or commands. Each vendor has its own manifest path. Example: `plugins/gitflow`.

**profile.** A named variant of a harness's configuration that can change hooks, MCP servers and
includes. Example: `redacted` and `counts` in `ynh/imessage/.agents/harness/plugin.json`.

**reference (skill file).** A file in a skill's `references/` folder that loads only when the
skill's body points at it. Example: `skills/platforms/skills/github/references/triage.md`.

**risk tier.** How much an agent may do. 0 is read only. 1 is preparing drafts that you send. 2
is acting only after your approval of each action. Every harness here is tier 0.

**sensor.** A declared observation surface in a harness: a build, test run or scan that a loop
driver runs and feeds back. No harness here declares one yet.

**seat.** A named role in a Wheelhouse with a lasting identity: its own harness in
`harnesses/<command>/`, its own charter, and its own memory in ynm. See
[Build a Wheelhouse](../wheelhouse/build-a-wheelhouse.md).

**skill.** A directory with a `SKILL.md` that gives a model knowledge or a procedure for one task.
Example: `skills/dev/skills/dev-review/SKILL.md`.

**SkillSpector.** NVIDIA's scanner that CI runs on every skill a pull request changes. Accepted
findings are in `.skillspector-baseline.yaml`.

**triage.** One of the four areas: platform-free questions about what needs you, answered per
platform. Skills in `skills/triage`, platform notes in `skills/platforms`. See
[How triage works](../triage/how-triage-works.md).

**vendor.** A tool that runs an agent: Claude Code, Cursor, Codex or Copilot CLI. See
[Vendors](../harnesses/vendors.md).

**wheelhouse.** One of the four areas: a team of named agent seats sharing a Beads work graph and
ynm memory, after Steve Yegge's essays. The `wheelhouse` plugin builds one. See
[Wheelhouse](../wheelhouse/README.md).

**ynd.** ynh's developer tool, used here by `pnpm lint` and `pnpm format` to lint and validate
harnesses.

**ynf.** Runs agent sessions contained, each in a container with only the credentials and
network its lane grants. The Wheelhouse's seats are meant to run in it.

**ynh.** The harness template manager that reads `.agents/harness/plugin.json` and produces each
vendor's native files. Its own docs are in its repository, not this one.

**ynm.** Shared memory for agents: memories with a type, a level and a namespace, synced through
a repository. Each Wheelhouse seat keeps its identity, handoff notes and Kudos in its own
namespace, `seat/<name>`.
