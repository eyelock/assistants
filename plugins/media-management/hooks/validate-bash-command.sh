#!/usr/bin/env bash
# Media Management safety hook — validates Bash commands before execution.
# Receives hook input as JSON on stdin:
# { "tool_name": "Bash", "tool_input": { "command": "..." }, ... }
#
# Exit 0 = allow, exit 2 = block (stderr message shown to Claude)

# Safety: if jq is not available, block everything — a safety hook must not fail open
if ! command -v jq &>/dev/null; then
  echo "BLOCKED: jq is required for the safety hook but is not installed. Install with: brew install jq" >&2
  exit 2
fi

COMMAND=$(jq -r '.tool_input.command // empty')

# If jq failed to parse or command is empty, block as a precaution
if [[ -z "$COMMAND" ]]; then
  echo "BLOCKED: Could not parse command from hook input." >&2
  exit 2
fi

# Block: extracting directly to Downloads root (not into a subfolder)
# Matches anywhere in the command (no $ anchor) to catch chained commands
if echo "$COMMAND" | grep -qE 'unzip.*-d[[:space:]]+["'"'"']?(~|/Users/[^/]+)/Downloads/?["'"'"']?([[:space:]]|;|&&|\|{1,2}|$)'; then
  echo "BLOCKED: Cannot extract directly to Downloads root. Extract to a subfolder instead." >&2
  exit 2
fi

# Block: rm -rf on Downloads, Music library, or archive root
if echo "$COMMAND" | grep -qE 'rm[[:space:]]+-rf?[[:space:]]+["'"'"']?(~|/Users/[^/]+)/(Downloads|Music|Storage/Music)["'"'"']?([[:space:]]|;|&&|\|{1,2}|$)'; then
  echo "BLOCKED: Cannot delete entire Downloads, Music, or archive directory." >&2
  exit 2
fi

# Block: any command touching common credential files
# Patterns are path-specific to avoid false positives
CRED_PATTERNS=(
  '\.ssh/'
  '\.aws/'
  '\.gnupg/'
  '\.gpg/'
  '\.netrc'
  '\.config/gh/'
  '\.kube/config'
  '\.docker/config'
  '/\.env([[:space:]]|;|&&|\||$)'
)
for pattern in "${CRED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo "BLOCKED: Command references credential path ($pattern). This plugin should not access credentials." >&2
    exit 2
  fi
done

# All safety checks passed — auto-approve this command
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Media management: command passed safety checks"
  }
}'
exit 0
