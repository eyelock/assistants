# Cursor — Hooks Reference

## Declaration Files

Plugin: hooks/hooks.json inside plugin directory
Project: .cursor/settings.json (committable)
Project-local: .cursor/settings.local.json (gitignored)
User: ~/.cursor/settings.json

## Hook Events (25 — same as Claude Code)

SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PermissionDenied,
PostToolUse, PostToolUseFailure, Notification, SubagentStart, SubagentStop,
TaskCreated, TaskCompleted, Stop, StopFailure, TeammateIdle, InstructionsLoaded,
ConfigChange, CwdChanged, FileChanged, WorktreeCreate, WorktreeRemove,
PreCompact, PostCompact, Elicitation, ElicitationResult, SessionEnd

## Hook Types

command, http, prompt, agent (same as Claude Code)

## TWO DIFFERENT FORMATS

### Plugin format (hooks/hooks.json) — flat, legacy camelCase event names:
{
  "hooks": {
    "beforeShellExecution": [
      {"command": "./scripts/validate.sh", "matcher": "rm|curl"}
    ],
    "afterFileEdit": [{"command": "./scripts/format.sh"}],
    "stop": [{"command": "./scripts/audit.sh"}]
  }
}

### Settings format (.cursor/settings.json) — three-level, PascalCase (same as Claude):
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "/path/to/script.sh", "timeout": 60}]
      }
    ]
  }
}

## Known ynh Discrepancy

ynh uses legacy flat format with plugin event names. Needs verification:
does Cursor read .cursor/hooks.json same as hooks/hooks.json inside plugin?
Event name mapping may differ between contexts.

## ynh Canonical Event Mapping (Cursor)

before_tool  → beforeShellExecution (plugin) / PreToolUse (settings)
after_tool   → afterFileEdit (plugin) / PostToolUse (settings)
before_prompt → beforeSubmitPrompt (plugin) / UserPromptSubmit (settings)
on_stop      → stop (plugin) / Stop (settings)
