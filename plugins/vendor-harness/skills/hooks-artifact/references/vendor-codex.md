# OpenAI Codex — Hooks Reference

Docs: https://developers.openai.com/codex/hooks
      https://github.com/openai/codex/tree/main/codex-rs/hooks/schema/generated

## Status

Experimental. Requires feature flag in config:
  [features]
  codex_hooks = true

## Declaration Files

Repo-level: <repo>/.codex/hooks.json
User-level: ~/.codex/hooks.json

## Hook Events (5 only)

SessionStart, PreToolUse, PostToolUse, UserPromptSubmit, Stop

## Hook Types

command only. No http, prompt, or agent types.

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
