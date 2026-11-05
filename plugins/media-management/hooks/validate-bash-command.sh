#!/usr/bin/env bash
# Media Management safety hook — validates Bash commands before execution.
# Receives hook input as JSON on stdin:
# { "tool_name": "Bash", "tool_input": { "command": "..." }, ... }
#
# Exit 2 = block (stderr message shown to Claude). Exit 0 with an "allow"
# decision = a single call to one of this plugin's scripts. Exit 0 with no
# output = defer to the normal permission flow.

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

# All safety checks passed. Auto-approve only a single call to one of this
# plugin's own scripts; every other command (this hook runs in every session,
# not just media work) goes through the normal permission flow. A command that
# chains, pipes, redirects or substitutes could run something else, so it is
# never auto-approved: quoted arguments are removed first, so "Artist & Band"
# in a path does not count, but $( and backticks count even inside quotes.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
unquoted=$(printf '%s' "$COMMAND" | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")
script_re="^(bash[[:space:]]+)?[\"']?$(printf '%s' "$PLUGIN_ROOT" | sed 's/[][\.*^$/]/\\&/g')/skills/[a-z0-9-]+/scripts/[a-z0-9-]+\.sh[\"']?([[:space:]]|$)"
if echo "$COMMAND" | grep -qE "$script_re" &&
  ! printf '%s' "$COMMAND" | grep -qE '\$\(|`' &&
  ! printf '%s' "$unquoted" | grep -qE '[;&|<>]'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "Media management: runs one of the plugin'"'"'s own scripts"
    }
  }'
fi
exit 0
