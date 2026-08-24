# GitHub Copilot CLI — Subagent Reference

Docs: https://docs.github.com/en/copilot/reference/custom-agents-configuration
      https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-custom-agents-for-cli

## Support Status

Full support. Copilot calls them **custom agents**.

## File Naming

`agents/<name>.agent.md` is the documented convention. Claude Code and Cursor use
`agents/<name>.md`.

**Both work.** Verified on v1.0.80: a probe plugin carrying `plain-style.md` and
`suffixed-style.agent.md` registered both, and the bare-`.md` agent ran successfully. Plugins
written for Claude Code need no renaming — `.agent.md` is a preference, not a requirement.

Locations:
- Plugin: `agents/` at plugin root (override with the `agents` field in `plugin.json`)
- Project: `.github/agents/`
- User: `~/.copilot/agents/`

The agent's ID is derived from the filename (minus `.md` / `.agent.md`), and that ID is what
deduplication keys on.

## Addressing

Plugin agents are namespaced `plugin-name:agent-name`. A bare name is rejected:

```
$ copilot --agent harness-advisor -p "..."
No such agent: harness-advisor, available: vendor-harness:harness-advisor, ...
```

The error helpfully enumerates every qualified name, which makes it a fast way to check what
actually registered — `copilot plugin list` does not itemise agents, and the install message
counts skills only ("Installed 12 skills" for a plugin that also shipped 4 agents).

## Frontmatter

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `description` | string | **yes** | drives model-side routing |
| `name` | string | no | display name |
| `target` | string | no | `vscode` or `github-copilot`; defaults to both |
| `tools` | list \| string | no | defaults to all tools |
| `model` | string | no | inherits the session model if unset |
| `disable-model-invocation` | boolean | no | default `false`; stops automatic dispatch |
| `user-invocable` | boolean | no | default `true`; whether a user can select it |
| `mcp-servers` | object | no | extra MCP servers/tools for this agent; ignored in VS Code |
| `metadata` | object | no | free-form annotation; ignored in VS Code |
| `infer` | boolean | no | **retired** — use `disable-model-invocation` + `user-invocable` |

Body prompt: max **30,000 characters**.

`description` is the only required field — unlike Claude Code, `name` is optional.

## Tool Names

Copilot accepts case-insensitive aliases, including the Claude tool names:

| Alias | Also accepts | Purpose |
|-------|--------------|---------|
| `execute` | `shell`, `Bash`, `powershell` | run shell commands |
| `read` | `Read`, `NotebookRead` | read file contents |
| `edit` | `Edit`, `MultiEdit`, `Write`, `NotebookEdit` | modify files |
| `search` | `Grep`, `Glob` | search files or file contents |
| `agent` | `custom-agent`, `Task` | invoke other agents |
| `web` | `WebSearch`, `WebFetch` | fetch URLs, web search |
| `todo` | `TodoWrite` | task lists (VS Code only) |

Patterns:
- omit `tools`, or `tools: ["*"]` → all tools
- explicit list → only those tools
- `tools: []` → **all tools disabled** (not "all allowed" — easy to get backwards)
- MCP tools: `server-name/tool-name` or `server-name/*`

Out-of-box MCP servers usable in `tools`: `github/*` (read-only, scoped to the source repo)
and `playwright/*` (localhost only).

## Delegation

Native subagent dispatch. `/fleet` runs subagents in parallel. Per-agent model overrides live
under the `subagents.agents` setting; `subagents.disabledSubagents` blocks specific agents
from being dispatched.

Versioning is by git commit SHA of the agent profile file.

## Precedence

First-found-wins by agent ID: built-in → user (`~/.copilot/agents/`) → project
(`.github/agents/`, `.claude/`) → inherited (monorepo parents) → plugin (install order) →
remote org/enterprise. Lowest level wins — a repository agent overrides an organization one,
which overrides an enterprise one.

## Porting From Claude Code

| Claude field | Copilot equivalent |
|--------------|--------------------|
| `name` | `name` (optional here) |
| `description` | `description` (required here) |
| `model` | `model` |
| `tools` (space-delimited) | `tools` (list; aliases accepted) |
| `disallowedTools` | no equivalent — enumerate the allowed set instead |
| `skills` | no equivalent — reference skills from the prompt body |
| `maxTurns`, `effort`, `memory`, `background`, `isolation`, `permissionMode` | no equivalent |
| `mcpServers` (array) | `mcp-servers` (object) |
| `hooks` in frontmatter | no equivalent — declare in `hooks.json` |

The filename can stay `.md`; only a `skills:` list has to be re-expressed as prose.
