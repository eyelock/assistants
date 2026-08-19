# OpenAI Codex — Subagent Reference

Docs: https://developers.openai.com/codex/plugins

## Support Status

Agents/subagents: NOT SUPPORTED in Codex plugin format.

Codex plugins support: skills, MCP servers.
Codex does NOT support: agents, rules, commands, delegates.

## Workaround

For multi-step flows in Codex, encode the orchestration logic in a skill or
in the AGENTS.md startup context. There is no subagent delegation mechanism.
