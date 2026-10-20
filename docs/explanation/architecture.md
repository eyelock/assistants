# Architecture

This repo is a worked example of how four agentic building blocks fit together: MCP servers,
plugins, agent skills and ynh harnesses. This page explains the shape and the reasons. For
lookups see [Harnesses](../reference/harnesses.md) and
[Triage questions](../reference/triage-questions.md).

## Three layers

```
ynh/<platform>            thin harness: picks skills, wires one MCP server, sets the guard
  |  includes
  v
skills/platforms/skills   vendor platform skills: how to work well in one tool
skills/triage/skills      generic triage skills: platform-free questions and answer shape
```

**Generic triage skills** (`skills/triage`) say what to ask and how to answer, without naming a
platform: `waiting-on-me`, `waiting-on-them`, `action-now-or-soon`, `my-commitments`,
`catch-up`, `find`, and `triage-report`, which holds the rules and the answer shape. A
question such as "what is waiting on me" is the same whether the inbox is mail or chat.

**Vendor platform skills** (`skills/platforms`) say where to look on one platform. Each has a
`SKILL.md` for the platform's rules and quirks, `references/tools.md` for the server's tools,
and `references/triage.md` mapping each triage question to the tools that answer it.

**Harnesses** (`ynh/<platform>`) are thin. A harness holds no knowledge of its own. Its
`plugin.json` includes `skills/triage` and picks one platform skill, declares the one MCP server,
and gives each triage question a focus.

## Why split them

- A new question is written once, in the triage layer, and every platform answers it the same
  way. The common list in `questions.json` keeps the platforms in step.
- A new platform is one platform skill and one thin harness. It does not touch the triage skills.
- The part that varies (the server, its credentials, what it can write) sits in the harness,
  where a person reviews it. The part that is judgement (what counts as waiting) sits in skills
  that any harness can reuse.
- A platform skill that explains the platform can be used on its own, without the harness.

## Where each feature is shown

**MCP servers.** Each platform harness declares one in `mcp_servers`: a remote URL (`github`,
`slack`) or a local command (`gmail`, `google-calendar`, `google-drive` and `imessage` through
`uvx` or `npx`, pinned to a version). Credentials are passed through from the environment with
`env_passthrough`, never written into the manifest.

**Plugins.** `plugins/` holds self-contained plugins (`gitflow`, `media-management`,
`vendor-harness`) and `skills/` holds domain plugins (`dev`, `tech`, `infra`, `pause`, and the
`triage` and `platforms` packages). Each carries manifests for Claude Code, Cursor and ynh, so one
directory installs in all three. The three marketplace indexes list them.

**Agent skills.** Every skill is a directory with a `SKILL.md` and YAML frontmatter, following
[agentskills.io](https://agentskills.io/specification), and ships its own `evals/`.

**ynh harnesses.** `ynh/` shows the harness features:

- *Includes and picks*: a harness composes skills from the shared library by git path and `pick`.
- *Profiles*: `ynh/imessage` has `redacted` and `counts`, which swap the server's privacy flag;
  `ynh/termq-dev` and `ynh/ynh-dev` have `thorough`, `quick` and `security`.
- *Focuses*: a named, ready-made prompt. Every platform harness has one per triage question.
- *Hooks*: `before_tool` on `ynh/apple-calendar` (branch `feat/apple-calendar`) blocks tools. See
  [Safety](safety.md).
- *Sensors*: no harness in this repo declares any yet.

For what each of these is in ynh itself, see the ynh docs.
