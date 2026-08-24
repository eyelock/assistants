---
name: subagent-artifact
description: Validate, diagnose, and understand subagent definitions (agents/*.md) — frontmatter format, delegation model, and vendor support across Claude Code, Cursor, Codex, and Copilot CLI.
---

Use this skill when working with agent definition files — validating frontmatter, diagnosing delegation failures, or understanding what each vendor supports.

**Frontmatter fields (Claude Code — most complete support):**
- `name`: required, agent identifier
- `description`: required, used to route work to this agent
- `model`: optional, override default model
- `tools`: optional, space-delimited allowed tools
- `disallowedTools`: optional, space-delimited blocked tools
- `skills`: optional, array of skill names to load
- `maxTurns`: optional, limit agent turns
- `effort`: optional
- `memory`, `background`, `isolation`: optional

**Directory layout:**
```
agents/
└── agent-name.md         # Claude Code, Cursor — also accepted by Copilot CLI
└── agent-name.agent.md   # Copilot CLI's documented convention
```

Copilot CLI accepts both extensions (verified on v1.0.80), so a Claude/Cursor plugin needs no
renaming. In Copilot, `description` is required but `name` is optional — the reverse of Claude,
where both are required. Copilot addresses plugin agents as `plugin-name:agent-name`; a bare
name is rejected with an error listing every qualified name available.

**Delegation model:** An agent is invoked when the orchestrating agent (or user) routes work to it. The delegate receives the harness's AGENTS.md instructions, rules (inlined), and skills (listed by reference).

**Vendor support matrix:** See references/ — Claude Code and Copilot CLI have full support,
Cursor supports `name`/`description` (plus optional `model`/`readonly`/`is_background`), and
Codex does not support agents in plugins at all.

**Tool naming:** Claude and Cursor use Claude tool names. Copilot accepts case-insensitive
aliases (`execute`, `read`, `edit`, `search`, `agent`, `web`, `todo`) *and* the Claude names.
In Copilot, `tools: []` disables all tools — it does not mean "all allowed".
