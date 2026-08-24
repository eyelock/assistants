---
name: hooks-artifact
description: Validate, diagnose, and understand hook configurations across Claude Code, Cursor, Codex, and Copilot CLI — event coverage, hook types, format differences, and why hooks may not fire.
---

Use this skill when working with hook configurations — validating format, diagnosing why a hook didn't fire, or understanding what events and types each vendor supports.

**Hook anatomy:**
- Event: when the hook fires (PreToolUse, PostToolUse, UserPromptSubmit, Stop, SessionStart, etc.)
- Matcher: optional filter (tool name, pattern) — support varies by vendor and event
- Hook type: command, http, prompt, agent (vendor support varies)
- Command: shell command to execute

**Nesting shape by vendor** — check this first, it is the most common silent failure:
- Claude Code / Codex: three-level — event → `[{matcher, hooks: [...]}]`
- Cursor / Copilot CLI: two-level — event → `[{...hook}]`
- Copilot CLI additionally requires a top-level `"version": 1`

**Diagnostic checklist for hooks that don't fire:**
1. Check the declaration file location — differs by vendor and context (plugin vs project vs user)
2. Check the nesting shape and, for Copilot, the `"version": 1` field
3. Check event name casing — Claude/Codex use PascalCase; Cursor uses flat camelCase names;
   Copilot accepts camelCase natively plus PascalCase Claude aliases (which also switch the
   payload shape and matcher vocabulary to Claude's)
4. Check the matcher — wrong tool name or pattern will silently skip the hook. Tool-name
   vocabularies differ: Claude's `Bash`/`Read`/`Edit` vs Copilot's `bash`/`view`/`edit`
5. Check vendor support — Codex is command-type only; Copilot's `prompt` type works on
   `sessionStart` only, and it has no `agent` or `mcp_tool` type
6. In Claude Code: hooks in plugins require `/plugin enable` + `/reload-plugins` — NOT auto-activated by --plugin-dir
7. In Copilot CLI: an installed plugin is a snapshot — reinstall after editing, or iterate with `copilot --plugin-dir ./my-plugin`
8. Check for a `disableAllHooks` switch higher up the chain (Claude settings, Copilot settings
   or policy files, Codex `[features] hooks = false`)

**Hook types by vendor:**
- Claude Code: command, http, prompt, agent, mcp_tool
- Cursor: command, http, prompt, agent
- Codex: command only (`prompt`/`agent` parsed but silently skipped)
- Copilot CLI: command, http, prompt (`sessionStart` only)

**Events by vendor:** See references/ — Claude Code has ~30, Cursor 18+, Copilot CLI 14
(plus 12 PascalCase Claude aliases), Codex 11.

**Failure semantics:** Copilot fails open on non-zero exits except `preToolUse` (fail-closed)
— but a *timeout* fails open even on `preToolUse`. Never rely on a slow Copilot hook to block
a tool call.
