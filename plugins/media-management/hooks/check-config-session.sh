#!/usr/bin/env bash
# SessionStart hook: nudges Claude to run /media-management:setup when a
# required MEDIA_MGMT_* path can't be resolved from env var or config.json.
set -euo pipefail

if ! command -v jq &>/dev/null; then
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
    "hookEventName": "SessionStart",
    "additionalContext": ("media-management plugin: required configuration is missing (" + $missing + "). Regardless of what the user says first this session, run /media-management:setup as part of your very first reply, before addressing anything else — do not wait for the user to mention media-management, downloads, or configuration.")
  }
}'
