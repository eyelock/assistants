#!/usr/bin/env bash
# Media Management session init — sets environment variables via CLAUDE_ENV_FILE.
# Maps config.json keys to MEDIA_MGMT_* env vars so they're available regardless
# of which directory Claude Code is launched from.

if [[ -z "$CLAUDE_ENV_FILE" || -z "$CLAUDE_PLUGIN_ROOT" ]]; then
  exit 0
fi

CONFIG_FILE="${CLAUDE_PLUGIN_ROOT}/config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

if ! command -v jq &>/dev/null; then
  exit 0
fi

# Map config.json keys to env var names
declare -A KEY_MAP=(
  [downloads]=MEDIA_MGMT_DOWNLOADS
  [library_import]=MEDIA_MGMT_LIBRARY_IMPORT
  [library_storage]=MEDIA_MGMT_LIBRARY_STORAGE
  [archive_workdir]=MEDIA_MGMT_ARCHIVE_WORKDIR
)

for config_key in "${!KEY_MAP[@]}"; do
  env_var="${KEY_MAP[$config_key]}"
  # Only set if not already in environment (user overrides take precedence)
  if [[ -z "${!env_var:-}" ]]; then
    value=$(jq -r --arg k "$config_key" '.[$k] // empty' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$value" ]]; then
      echo "${env_var}=${value}" >> "$CLAUDE_ENV_FILE"
    fi
  fi
done

exit 0
