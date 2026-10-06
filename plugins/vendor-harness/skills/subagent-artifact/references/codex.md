# OpenAI Codex — Subagent Reference

Docs: https://developers.openai.com/codex/plugins/build
      https://learn.chatgpt.com/docs/agent-configuration/subagents

## Support Status

Plugins: NO agents. A Codex plugin carries skills, MCP servers, apps and lifecycle hooks; an
`agents/` directory in it is ignored.

Standalone custom agents: SUPPORTED, outside plugins.
- Project: `.codex/agents/<name>.toml`; personal: `~/.codex/agents/<name>.toml`
- One agent per file, in TOML, not Markdown with frontmatter
- Required: `name`, `description`, `developer_instructions` (the agent's prompt)
- Optional: session config keys such as `model`, `model_reasoning_effort`, `sandbox_mode`,
  `mcp_servers`, `skills.config`
- Global limits live under `[agents]` in `config.toml` (`enabled`,
  `max_concurrent_threads_per_session`, `default_subagent_model`, ...)

```toml
name = "triager"
description = "Triage a new issue: label it, find duplicates, suggest an owner."
developer_instructions = """
Read the issue, search for duplicates, then...
"""
```

## Porting a Claude agent to Codex

A plugin cannot install it. Either ship the flow as a skill (or in AGENTS.md), which the
plugin can carry, or tell users to add a `.codex/agents/<name>.toml` themselves, converting the
Markdown body to `developer_instructions`. Claude's `tools:` has no direct equivalent;
`sandbox_mode` is the nearest control.
