# OpenAI Codex — Hooks Reference

Docs: https://learn.chatgpt.com/docs/hooks (redirected from developers.openai.com/codex/hooks)
      https://github.com/openai/codex/tree/main/codex-rs/hooks/schema/generated

## Status

Enabled by default. Disable via feature flag in config:
  [features]
  hooks = false
(Flag was previously named `codex_hooks`; renamed to `hooks`.)

## Declaration Files

Repo-level: <repo>/.codex/hooks.json
User-level: ~/.codex/hooks.json

## Hook Events (11)

SessionStart, SessionEnd, PreToolUse, PostToolUse, UserPromptSubmit, Stop,
SubagentStart, SubagentStop, PermissionRequest, PreCompact, PostCompact

## Hook Types

command only. `prompt` and `agent` types are parsed but silently skipped (not executed).

## Format

{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/script.py",
            "statusMessage": "Checking command",
            "timeout": 600
          }
        ]
      }
    ]
  }
}

## Codex-specific fields

statusMessage: display text shown during hook execution
timeoutSec: alias for timeout
additionalContextLimit: caps how much hook output is added back into context
async: run hook without blocking the turn
description (top-level in hooks.json): human-readable label for the hook set

## Matcher behavior

PreToolUse/PostToolUse: filter on tool_name
SessionStart: filter on source (startup|resume)
UserPromptSubmit, Stop: matcher not supported

## Execution

Multiple matching hooks run CONCURRENTLY (not sequentially).
Output MUST be JSON on stdout when exit 0.

## ynh Canonical Event Mapping (Codex)

before_tool   → PreToolUse
after_tool    → PostToolUse
before_prompt → UserPromptSubmit
on_stop       → Stop
(SessionStart not yet mapped — LOW priority gap)
