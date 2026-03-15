#!/usr/bin/env bash
# Media Management auto-approve hook — frictionless approval for safe tool calls.
# Used for Read, Skill, Glob, Grep tools that don't need the full Bash safety checks.
# Receives hook input as JSON on stdin.

# Safety: if jq is not available, fall back to default permission flow
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# For Read/Glob/Grep: block credential paths (since plugin settings.json deny
# list may not apply when launched from another directory)
if [[ "$TOOL_NAME" == "Read" || "$TOOL_NAME" == "Glob" || "$TOOL_NAME" == "Grep" ]]; then
  # Extract the file path or search path from tool input
  TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.pattern // empty')

  CRED_PATTERNS=(
    '\.ssh/'
    '\.aws/'
    '\.gnupg/'
    '\.gpg/'
    '\.netrc'
    '\.config/gh/'
    '\.kube/config'
    '\.docker/config'
    '/\.env$'
    '/\.env\.'
    'credentials'
    '/secrets/'
    '\.pem$'
    '\.key$'
    '_rsa$'
    '_ed25519$'
  )

  for pattern in "${CRED_PATTERNS[@]}"; do
    if echo "$TARGET" | grep -qiE "$pattern"; then
      jq -n '{
        "hookSpecificOutput": {
          "hookEventName": "PreToolUse",
          "permissionDecision": "deny",
          "permissionDecisionReason": "Blocked: credential path"
        }
      }'
      exit 0
    fi
  done
fi

# Auto-approve
jq -n --arg tool "$TOOL_NAME" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": ("Media management: auto-approved " + $tool)
  }
}'
exit 0
