---
name: hooks-artifact
description: Validate, diagnose, and understand hook configurations across Claude Code, Cursor, and Codex — event coverage, hook types, format differences, and why hooks may not fire.
---

Use this skill when working with hook configurations — validating format, diagnosing why a hook didn't fire, or understanding what events and types each vendor supports.

**Hook anatomy:**
- Event: when the hook fires (PreToolUse, PostToolUse, UserPromptSubmit, Stop, SessionStart, etc.)
- Matcher: optional filter (tool name, pattern) — support varies by vendor and event
- Hook type: command, http, prompt, agent (vendor support varies)
- Command: shell command to execute

**Diagnostic checklist for hooks that don't fire:**
1. Check the declaration file location — differs by vendor and context (plugin vs project vs user)
2. Check event name casing — Claude/Cursor use PascalCase; Cursor plugin format uses camelCase legacy names
3. Check the matcher — wrong tool name or pattern will silently skip the hook
4. Check vendor support — Codex only supports 5 events and command type only
5. In Claude Code: hooks in plugins require `/plugin enable` + `/reload-plugins` — NOT auto-activated by --plugin-dir
6. In Codex: hooks are experimental and require `[features] codex_hooks = true` in config.toml

**Hook types by vendor:**
- Claude Code: command, http, prompt, agent
- Cursor: command, http, prompt, agent
- Codex: command only

**Events by vendor:** See references/ — Claude Code and Cursor have 25 events; Codex has 5.
