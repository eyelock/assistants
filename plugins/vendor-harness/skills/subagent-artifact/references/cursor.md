# Cursor — Subagent Reference

Docs: https://cursor.com/docs/subagents
      https://cursor.com/docs/reference/plugins

## Support Status

Supported — confirmed via cursor.com/docs/subagents (eyelock/ynh#200, 2026-08-19).
ynh's delegate generator (`BuildDelegateAgent`) already emits the `name`/`description`
frontmatter Cursor needs.

## Locations

Plugin: agents/<name>.md at plugin root
Project: .cursor/agents/, plus .claude/agents/ and .codex/agents/ for compatibility
User: ~/.cursor/agents/, ~/.claude/agents/, ~/.codex/agents/

Project subagents win over user ones; on a name clash, `.cursor/` wins.

## Supported Fields

| Field | Notes |
|-------|-------|
| `name` | kebab-case; required for plugin agents, otherwise derived from the filename |
| `description` | required for plugin agents; drives delegation routing |
| `model` | optional, default `inherit` |
| `readonly` | optional, default `false` |
| `is_background` | optional, default `false` |

Claude-only fields (`tools`, `skills`, `maxTurns`, `permissionMode`, ...) are ignored
without warning. Because `skills:` is inert, name any skill the agent depends on in the
prompt body as an explicit instruction.
