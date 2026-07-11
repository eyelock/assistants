#!/usr/bin/env bash
# PreToolUse gate: blocks Bash calls into config-dependent skill scripts when
# required MEDIA_MGMT_* config is missing, and points Claude at /media-management:setup.
set -euo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Skills whose scripts read the MEDIA_MGMT_* path config
GATED_SKILLS='process-album|select-release|cleanup|manage-metadata|import-to-apple-music|archive-media'

if ! echo "$COMMAND" | grep -qE "skills/(${GATED_SKILLS})/scripts/"; then
  exit 0
fi

RESULT=$("${CLAUDE_PLUGIN_ROOT}/skills/setup/scripts/check-config.sh" 2>/dev/null) || exit 0

OK=$(echo "$RESULT" | jq -r 'if .ok == false then "false" else "true" end')
if [[ "$OK" == "true" ]]; then
  exit 0
fi

MISSING=$(echo "$RESULT" | jq -r '.missing_required | join(", ")')

jq -n --arg missing "$MISSING" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": ("Required media-management configuration is missing (" + $missing + "). Run /media-management:setup to configure it, then retry.")
  }
}'
