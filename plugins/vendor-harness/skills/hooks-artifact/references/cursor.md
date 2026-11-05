# Cursor — Hooks Reference

Docs: https://cursor.com/docs/hooks
      https://cursor.com/docs/reference/plugins
      https://cursor.com/docs/reference/third-party-hooks

## Declaration Files

Plugin: hooks/hooks.json at plugin root (or `"hooks": "hooks/hooks.json"` in .cursor-plugin/plugin.json)
Project: .cursor/hooks.json
User: ~/.cursor/hooks.json
Enterprise: OS-level hooks.json (e.g. /Library/Application Support/Cursor/hooks.json on macOS)

There is no `.cursor/settings.json` for hooks. Every location uses the same flat format and
camelCase event names; only the path differs.

## Hook Events (21: 18 agent, 2 Tab, 1 app lifecycle)

Agent: sessionStart, sessionEnd, preToolUse, postToolUse, postToolUseFailure,
subagentStart, subagentStop, beforeShellExecution, afterShellExecution,
beforeMCPExecution, afterMCPExecution, beforeReadFile, afterFileEdit,
beforeSubmitPrompt, preCompact, stop, afterAgentResponse, afterAgentThought
Tab: beforeTabFileRead, afterTabFileEdit
App lifecycle: workspaceOpen

## Hook Types

command (default), prompt. No http, agent, or mcp_tool type.
Cloud agents run command hooks only.

## Format — two-level, camelCase

{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      {"command": "./scripts/validate.sh", "matcher": "rm|curl"}
    ],
    "afterFileEdit": [{"command": "./scripts/format.sh"}],
    "stop": [{"command": "./scripts/audit.sh"}]
  }
}

The hooks docs require `"version": 1` in hooks.json; the plugin reference's hooks/hooks.json
example omits it. Including it is harmless. Per-hook options: command, type, timeout,
loop_limit, failClosed, matcher. Exit code 2 blocks the action (as in Claude Code); other
non-zero codes fail open.

A Claude-format file (three-level `{matcher, hooks: [...]}`, PascalCase events) does not
bind as a Cursor plugin hooks file.

## Claude Code Hooks (third-party loading)

With "Include Third-Party Plugins, Skills, and Other Configs" enabled, Cursor also loads
hooks from .claude/settings.local.json, .claude/settings.json and ~/.claude/settings.json,
mapping PreToolUse, PostToolUse, UserPromptSubmit (→ beforeSubmitPrompt), Stop,
SubagentStop, SessionStart, SessionEnd and PreCompact. Notification and PermissionRequest
are not supported. This covers Claude settings files, not a plugin's hooks/hooks.json.

## ynh Export

ynh writes both `.cursor/hooks.json` (project) and `hooks/hooks.json` (plugin root) with
identical flat content (eyelock/ynh#197 / #203; see known-gaps in vendor-adapters).

## ynh Canonical Event Mapping (Cursor)

before_tool      → beforeShellExecution
after_tool       → afterFileEdit
before_prompt    → beforeSubmitPrompt
on_stop          → stop
on_session_start → sessionStart  (eyelock/ynh#204)
