#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/manage-metadata/scripts/extract-apple-music-genres.sh"

# Test 1: Script runs and returns valid JSON
# Capture both stdout and exit code — don't mask errors with fallback
output=$(bash "$SCRIPT" 2>/dev/null) || {
  rc=$?
  echo "FAIL: Script exited with code $rc"
  exit 1
}
echo "$output" | jq . > /dev/null 2>&1 || {
  echo "FAIL: Output is not valid JSON: $output"
  exit 1
}

# Test 2: JSON has expected structure
has_genres=$(echo "$output" | jq 'has("genres")')
has_source=$(echo "$output" | jq 'has("source")')
if [[ "$has_genres" != "true" || "$has_source" != "true" ]]; then
  echo "FAIL: Missing expected keys (genres, source)"
  exit 1
fi

# Test 3: genres is an array
is_array=$(echo "$output" | jq '.genres | type == "array"')
if [[ "$is_array" != "true" ]]; then
  echo "FAIL: genres should be an array"
  exit 1
fi

# Test 4: source is a recognized value
source=$(echo "$output" | jq -r '.source')
case "$source" in
  applescript-genres|mdfind|applescript-tracks|none)
    ;;
  *)
    echo "FAIL: Unexpected source value: $source"
    exit 1
    ;;
esac

echo "All extract-apple-music-genres tests passed (source: $source, genres: $(echo "$output" | jq '.genres | length'))"
