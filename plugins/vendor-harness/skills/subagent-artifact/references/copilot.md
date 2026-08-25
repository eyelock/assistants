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

## Tool Names — two vocabularies, and the aliases do not work in `tools:`

**`tools` restricts.** Omit it and the agent gets everything; list it and the agent gets only
what resolves. Claude and Copilot do not share a tool namespace, so a Claude-authored `tools:`
list silently strips capability on Copilot.

Tested on v1.0.80 with one probe plugin, varying only the `tools:` line, asking the agent to
fetch a URL:

| `tools:` value | Fetch works? |
|----------------|--------------|
| *(field omitted)* | ✓ |
| `Read, Write, WebFetch, Bash` (Claude names) | ✗ **blocked** |
| `read, edit, execute, web` (GitHub's documented aliases) | ✗ **blocked** |
| `view, edit, bash, web_fetch` (raw Copilot names) | ✓ |
| `Read, Write, WebFetch, Bash, web_fetch, web_search` (union) | ✓ |

Two things follow. First, GitHub's published alias table below is **not reliable for `tools:`**
— `web` is documented as the alias for `WebFetch`/`WebSearch`, and neither `web` nor `WebFetch`
grants fetch. Only the raw `web_fetch` does. Second, the portable fix is to **list both
vocabularies**; extra names that a vendor does not recognise are ignored rather than fatal.

This is what broke this plugin's own `vendor-sync` agent: `tools: Read, Write, WebFetch, Bash`
left it unable to fetch vendor documentation on Copilot, which is the only thing it exists to
do. It failed honestly — it reported what it could not verify rather than inventing a diff —
but it could not do its job.

The published alias table, which does apply to the model's own tool selection:

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
| `skills` | **no equivalent — inert, and silently so. See below.** |
| `maxTurns`, `effort`, `memory`, `background`, `isolation`, `permissionMode` | no equivalent |
| `mcpServers` (array) | `mcp-servers` (object) |
| `hooks` in frontmatter | no equivalent — declare in `hooks.json` |

The filename can stay `.md`; only a `skills:` list has to be re-expressed as prose.

## The `skills:` frontmatter trap

`skills:` is a Claude Code-only field that preloads named skills into an agent. Copilot parses
the agent and ignores the key. There is no warning, no missing-agent error, nothing in the
logs — the agent loads and runs, just without any of the knowledge it was built around, and
answers from the base model instead.

For a diagnostic or reference agent this is the worst possible failure mode: it produces a
confident, fluent, wrong answer. Observed directly on v1.0.80 with this plugin's own
`harness-advisor`, which claimed Copilot rejects `{"source":"github","repo":...}` object
sources — the exact opposite of the truth, and contradicted by the marketplace it was
installed from. The same question asked without the agent wrapper invoked `vendor-adapters`
correctly and answered right.

**Fix:** name the skills in the agent's prompt body as an explicit instruction, and say why.

```markdown
## Skills

The `skills:` frontmatter above is a Claude Code convenience. No other vendor honours it —
on Cursor, Codex, and Copilot CLI it is inert. The skills are installed and invocable; load
them yourself, by name, before relying on what they contain.

Load `vendor-adapters` for any question about how a vendor behaves.
```

Keep the `skills:` key as well — it still works on Claude, and the prose is harmless there.
This is the portable pattern for every Claude-only frontmatter field with no vendor
equivalent: state the intent in the body, keep the key for the vendor that honours it.

## Model Aliases Do Not Port

`model: sonnet` (a Claude alias) does not resolve:

```
Warning: Custom agent "vendor-harness:harness-advisor" specifies model "sonnet"
which is not available; using "auto" instead
```

Non-fatal — Copilot warns and falls back to `auto`. Either drop `model` so each vendor picks
its default, or accept a startup warning on non-Claude vendors. Copilot's own model names
(e.g. `gpt-5.2`, `claude-sonnet-4.6`) would break the Claude side instead, so there is no
single value that satisfies both.
