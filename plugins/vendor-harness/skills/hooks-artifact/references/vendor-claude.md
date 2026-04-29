# Claude Code — Hooks Reference

Docs: https://code.claude.com/docs/en/hooks-guide

## Declaration Files

Plugin: hooks/hooks.json inside plugin directory
Project: .claude/settings.json or .claude/settings.local.json
User: ~/.claude/settings.json

## Hook Events (25)

SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PermissionDenied,
PostToolUse, PostToolUseFailure, Notification, SubagentStart, SubagentStop,
TaskCreated, TaskCompleted, Stop, StopFailure, TeammateIdle, InstructionsLoaded,
ConfigChange, CwdChanged, FileChanged, WorktreeCreate, WorktreeRemove,
PreCompact, PostCompact, Elicitation, ElicitationResult, SessionEnd

## Hook Types

command, http, prompt, agent

## Format (three-level nesting, PascalCase event names)

{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "/path/to/script.sh", "timeout": 600}
        ]
      }
    ]
  }
}

## Plugin Activation

--plugin-dir does NOT auto-activate hooks.
Requires /plugin enable followed by /reload-plugins.

## Environment Variables

${CLAUDE_PLUGIN_ROOT}, ${CLAUDE_PLUGIN_DATA} available in hook scripts.
