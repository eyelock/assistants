---
name: subagent-artifact
description: Validate, diagnose, and understand subagent definitions (agents/*.md) — frontmatter format, delegation model, and vendor support across Claude Code, Cursor, and Codex.
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
└── agent-name.md    # agent definition
```

**Delegation model:** An agent is invoked when the orchestrating agent (or user) routes work to it. The delegate receives the harness's AGENTS.md instructions, rules (inlined), and skills (listed by reference).

**Vendor support matrix:** See references/ — Codex does not support agents in plugins. Cursor support is partial. Claude Code has full support.
