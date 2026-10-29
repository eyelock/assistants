# Vendors

Claude Code, Cursor, Codex and GitHub Copilot CLI all run an agent loop, and all four have
adopted some of the same ideas. They differ in file names, in what a plugin may contain, and in
the details that break a port. This page explains where they agree and where they do not, for the
features in [Agentic features](../start/agentic-features.md).

Everything here comes from the reference files of the `vendor-harness` plugin
(`plugins/vendor-harness/skills/vendor-adapters/references/` and the `references/` folders under
`skill-artifact`, `hooks-artifact` and `mcp-artifact`). Those files are dated around August 2026
and the vendors change fast, so read this as a snapshot. [What could not be confirmed](#what-could-not-be-confirmed)
at the end says which claims were checked and which were not.

## The short version

- **Skills are the common ground.** One `SKILL.md` works in all four.
- **Plugins and marketplaces are similar in idea, different in files.** Each vendor has its own
  manifest path and index path. Copilot reads Claude's, which makes it the easiest port.
- **Hooks and MCP are where ports break**: event names, nesting and file names differ.

## Skills

| | Claude Code | Cursor | Codex | Copilot CLI |
|---|---|---|---|---|
| In a plugin | `skills/<name>/SKILL.md` | same | same | same |
| Project folders read | `.claude/skills` | `.cursor/skills`, `.agents/skills`, `.claude/skills`, `.codex/skills` | `.agents/skills` (not `.claude/skills`) | `.github/skills`, `.claude/skills`, `.agents/skills` |
| Personal folder | `~/.claude/skills` | the same four under `~/` | `$HOME/.agents/skills` | `~/.copilot/skills`, `~/.agents/skills` |
| Beyond the standard | extensions such as `disable-model-invocation`, `user-invocable`, `model` | `paths`, `disable-model-invocation`; ignores the other Claude extensions | standard fields only; turning off implicit use lives in `agents/openai.yaml` | `allowed-tools`; Claude extensions not documented for the CLI |

Two things to know. Claude Code demotes a skill that uses the optional `compatibility`, `license`
or `metadata` fields, so it is effectively invisible to the model; the skills here avoid them.
And a skill whose frontmatter does not parse still loads in Claude Code but with empty metadata,
so typing `/name` works while the model never picks it. Both are in
`plugins/vendor-harness/skills/skill-artifact/references/claude.md`.

## Plugins

| | Claude Code | Cursor | Codex | Copilot CLI |
|---|---|---|---|---|
| Manifest | `.claude-plugin/plugin.json` | `.cursor-plugin/plugin.json` | `.codex-plugin/plugin.json` | `plugin.json`, falling back to `.claude-plugin/plugin.json` |
| Required fields | `name` | `name`, `version`, `description` | `name`, `version`, `description` | `name` (kebab-case) |
| Can contain | skills, commands, agents, hooks, MCP, LSP, workflows, output styles | skills, rules, agents, commands, hooks, MCP | skills, MCP, apps; no agents, rules or commands | skills, agents, hooks, MCP, LSP, commands |
| Try one locally | `--plugin-dir` | copy to `~/.cursor/plugins/local/` (from this repo's README) | copy skills to `~/.agents/skills/` | `--plugin-dir` |

In this repo every plugin has the Claude and Cursor manifests plus a ynh one; only
`plugins/vendor-harness` also has a Codex manifest. ynh is not a vendor; its manifest is the input
ynh translates into the four.

## Marketplaces

| | Claude Code | Cursor | Codex | Copilot CLI |
|---|---|---|---|---|
| Index | `.claude-plugin/marketplace.json` | `.cursor-plugin/marketplace.json` | `.agents/plugins/marketplace.json` | `.github/plugin/marketplace.json`, then `marketplace.json`, `.plugin/`, `.claude-plugin/` |
| Who can add one | any user | Teams and Enterprise (this repo's README) | manual install (this repo's README) | any user |
| Source types | many, including `git-subdir`, `npm`, `archive`, `command` | not covered in the references | a `source` object with a `policy` object | exactly three: relative path, `github`, `url` |

The Codex index has a different shape from the other three. The Copilot row is the one that bites:
Copilot validates the whole index, so one `git-subdir`, `npm`, `archive` or `command` entry makes
every plugin in the marketplace uninstallable from Copilot, not just that entry. That is why this
repo has a separate `.github/plugin/marketplace.json`. The reference records it reproduced on
Copilot CLI v1.0.80.

## Hooks

| | Claude Code | Cursor | Codex | Copilot CLI |
|---|---|---|---|---|
| Plugin file | `hooks/hooks.json` | `hooks/hooks.json` | `.codex/hooks.json` (repo or user) | `hooks.json` or `hooks/hooks.json` |
| Event style | PascalCase, about 30 events | camelCase, 21 events | PascalCase, 11 events | camelCase, with PascalCase aliases; 14 events |
| Shape | three levels: event, `{matcher, hooks: []}`, hook | flat, two levels, `"version": 1` | three levels, like Claude | two levels, `"version": 1` required |
| Hook types | command, http, prompt, agent, mcp_tool | command, prompt | command only (others parsed, not run) | 3 types |
| Can block | yes | yes | yes | yes, but see below |

For the same moment, "before a tool runs", the names are `PreToolUse` (Claude, Codex, and a Copilot
alias), `preToolUse` (Cursor, Copilot) and `before_tool` (ynh's canonical name). A hook file
written for one will not bind on another without translation. Details that matter for safety:
Codex runs multiple matching hooks concurrently and requires JSON on stdout at exit 0; Copilot
timeouts on `preToolUse` fail open while a non-zero exit fails closed, so a slow security hook
silently permits the call.

`plugins/media-management/hooks/hooks.json` is in Claude's format. The same plugin has a
`.codex/config.toml` for Codex, which covers the sandbox and environment, not hooks.

## MCP servers

| | Claude Code | Cursor | Codex | Copilot CLI |
|---|---|---|---|---|
| Plugin file | `.mcp.json` | `mcp.json` (no dot) | `.mcp.json` | `.mcp.json` or `.github/mcp.json` |
| Project / user | `.mcp.json`; `~/.claude/mcp.json` | `.cursor/mcp.json`, `~/.cursor/mcp.json` | not covered in the references | `.mcp.json`; `~/.copilot/mcp-config.json` |
| Transports | stdio, HTTP, WebSocket | stdio, SSE, streamable HTTP | stdio only; HTTP and SSE not supported | stdio (`local` alias), HTTP, SSE |
| Other | the plugin's `mcpServers` merges with `.mcp.json`; `--plugin-dir` does not start its servers | `${env:NAME}` interpolation | the manifest must point at `.mcp.json` | duplicate names: last wins, with a warning |

All four use the same outer shape, `{"mcpServers": {...}}`, with `command`, `args` and `env` for a
local server. Codex's reference says stdio only, while ynh's `ynh/github` and `ynh/slack` harnesses
declare remote servers, so those two may not work on Codex (not tested). The differences are file names and type spellings: `"type": "stdio"` is the portable
spelling, because Copilot's `"local"` is not recognized by Claude Code or Codex.

## Instructions

`README.md` summarizes the files each tool reads: `CLAUDE.md` for Claude Code (this repo's goes
through `@AGENTS.md`), `AGENTS.md` and `.cursor/rules/*.mdc` for Cursor, `AGENTS.md` for Codex,
and `AGENTS.md`, `CLAUDE.md` and `.github/copilot-instructions.md` for Copilot. Cursor ignores a
plain `.md` rule: it must be `.mdc` with frontmatter.

## What could not be confirmed

- **Most rows were read from vendor documentation by the reference files' authors, not run for this
  page.** Only the Copilot CLI behaviors are recorded as checked against a binary (v1.0.80, on
  2026-08-24). Claude Code, Cursor and Codex rows rest on their docs.
- **The vendors' docs and binaries disagree in places** (the reference file for Copilot records
  `copilot plugins list` as documented but not present, and `--plugin-dir` as present but not
  documented). Treat any row as a claim to re-check on your own version.
- **Cursor marketplace source types, and where Codex reads user or project MCP servers**, are not in
  the references.
- **ynh has no Copilot adapter** (an open gap): Copilot works with this repo because it reads the
  Claude manifests, not because ynh generates Copilot files.
- **Whether a Codex marketplace index exists here.** `README.md` lists
  `.agents/plugins/marketplace.json`, but no such file is in the repo.
- Version numbers and event counts will drift. The references carry dates; check them before
  relying on a count.

To refresh any of this, the `vendor-harness` plugin has a `vendor-sync` agent and a
`fetch-vendor-docs` skill. They were not run for this page.
