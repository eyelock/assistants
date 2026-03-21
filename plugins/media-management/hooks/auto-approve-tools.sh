#!/usr/bin/env bash
# Media Management auto-approve hook — approves Read/Glob/Grep/Skill calls
# only when they target paths within the configured media management directories.
# Uses the same fallback chain as the skills: env var → config.json.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# --- Skill calls: always auto-approve (plugin-scoped orchestration) ---
if [[ "$TOOL_NAME" == "Skill" ]]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "Media management: skill orchestration"
    }
  }'
  exit 0
fi

# --- Read/Glob/Grep: approve only if path is within configured directories ---

# Extract the target path from tool input
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# If no path to check, defer to normal permission flow
if [[ -z "$TARGET" ]]; then
  exit 0
fi

# Resolve to absolute path (handles relative paths, trailing slashes, etc.)
# Use the path as-is if it's already absolute
if [[ "$TARGET" != /* ]]; then
  TARGET="$(pwd)/$TARGET"
fi

# Resolve configured paths: env var → config.json fallback
CONFIG_FILE="${CLAUDE_PLUGIN_ROOT:-}/config.json"

resolve_path() {
  local env_var="$1"
  local config_key="$2"

  # Try env var first
  local value="${!env_var:-}"
  if [[ -n "$value" ]]; then
    echo "$value"
    return
  fi

  # Fall back to config.json
  if [[ -f "$CONFIG_FILE" ]]; then
    value=$(jq -r --arg k "$config_key" '.[$k] // empty' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$value" ]]; then
      echo "$value"
      return
    fi
  fi
}

# Build list of allowed base paths
ALLOWED_PATHS=()

path=$(resolve_path MEDIA_MGMT_DOWNLOADS downloads)
[[ -n "$path" ]] && ALLOWED_PATHS+=("$path")

path=$(resolve_path MEDIA_MGMT_LIBRARY_IMPORT library_import)
[[ -n "$path" ]] && ALLOWED_PATHS+=("$path")

path=$(resolve_path MEDIA_MGMT_LIBRARY_STORAGE library_storage)
[[ -n "$path" ]] && ALLOWED_PATHS+=("$path")

path=$(resolve_path MEDIA_MGMT_ARCHIVE_WORKDIR archive_workdir)
[[ -n "$path" ]] && ALLOWED_PATHS+=("$path")

# Also allow reading plugin files (skills, scripts, config, CLAUDE.md)
if [[ -n "$CLAUDE_PLUGIN_ROOT" ]]; then
  ALLOWED_PATHS+=("$CLAUDE_PLUGIN_ROOT")
fi

# Check if target is under any allowed path
for allowed in "${ALLOWED_PATHS[@]}"; do
  if [[ "$TARGET" == "$allowed"* ]]; then
    jq -n '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": "Media management: path within configured directory"
      }
    }'
    exit 0
  fi
done

# Path not in any configured directory — defer to normal permission flow
exit 0
