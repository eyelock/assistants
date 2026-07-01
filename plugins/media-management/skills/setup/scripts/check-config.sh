#!/usr/bin/env bash
# Check which MEDIA_MGMT_* paths are resolvable (env var or config.json) and
# which required ones are still missing. Outputs JSON; never fails the caller.
set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo '{"error": "jq not installed", "ok": false}'
  exit 0
fi

CONFIG_PATH="${MEDIA_MGMT_CONFIG_PATH:-$HOME/.config/media-management/config.json}"

# key:env_var:required
KEYS=(
  "downloads:MEDIA_MGMT_DOWNLOADS:true"
  "library_import:MEDIA_MGMT_LIBRARY_IMPORT:true"
  "library_storage:MEDIA_MGMT_LIBRARY_STORAGE:true"
  "archive_workdir:MEDIA_MGMT_ARCHIVE_WORKDIR:true"
  "processed:MEDIA_MGMT_PROCESSED:false"
  "rekordbox_mcp_path:MEDIA_MGMT_REKORDBOX_MCP_PATH:false"
)

ITEMS="[]"
MISSING="[]"

for entry in "${KEYS[@]}"; do
  IFS=':' read -r key env_var required <<<"$entry"

  value=""
  source="missing"

  env_value="${!env_var:-}"
  if [[ -n "$env_value" ]]; then
    value="$env_value"
    source="env"
  elif [[ -f "$CONFIG_PATH" ]]; then
    config_value=$(jq -r --arg k "$key" '.[$k] // empty' "$CONFIG_PATH" 2>/dev/null)
    if [[ -n "$config_value" ]]; then
      value="$config_value"
      source="config"
    fi
  fi

  ITEM=$(jq -n \
    --arg key "$key" --arg env_var "$env_var" --argjson required "$required" \
    --arg value "$value" --arg source "$source" \
    '{key: $key, env_var: $env_var, required: $required, value: (if $value == "" then null else $value end), source: $source}')
  ITEMS=$(echo "$ITEMS" | jq --argjson item "$ITEM" '. + [$item]')

  if [[ "$required" == "true" && "$source" == "missing" ]]; then
    MISSING=$(echo "$MISSING" | jq --arg k "$key" '. + [$k]')
  fi
done

OK=true
[[ "$(echo "$MISSING" | jq 'length')" -gt 0 ]] && OK=false

jq -n \
  --arg config_path "$CONFIG_PATH" \
  --argjson config_exists "$([[ -f "$CONFIG_PATH" ]] && echo true || echo false)" \
  --argjson items "$ITEMS" \
  --argjson missing_required "$MISSING" \
  --argjson ok "$OK" \
  '{config_path: $config_path, config_exists: $config_exists, items: $items, missing_required: $missing_required, ok: $ok}'
