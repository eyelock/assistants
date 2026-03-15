#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/manage-metadata/scripts/inspect-metadata.sh"
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Setup: copy test MP3s
cp "$FIXTURES_DIR"/track*.mp3 "$TEST_TMPDIR/"

# Test 1: Basic inspection returns valid JSON with correct file count
output=$(bash "$SCRIPT" "$TEST_TMPDIR")
file_count=$(echo "$output" | jq '.files | length')
if [[ "$file_count" -ne 3 ]]; then
  echo "FAIL: Expected 3 files, got $file_count"
  exit 1
fi

# Test 2: Metadata fields are present
first_artist=$(echo "$output" | jq -r '.files[0].artist')
if [[ "$first_artist" != "Test Artist" ]]; then
  echo "FAIL: Expected artist 'Test Artist', got '$first_artist'"
  exit 1
fi

# Test 3: Empty folder returns empty array
empty_dir="$TEST_TMPDIR/empty"
mkdir -p "$empty_dir"
output=$(bash "$SCRIPT" "$empty_dir")
file_count=$(echo "$output" | jq '.files | length')
if [[ "$file_count" -ne 0 ]]; then
  echo "FAIL: Expected 0 files for empty dir, got $file_count"
  exit 1
fi

# Test 4: Missing folder returns exit code 2
if bash "$SCRIPT" "/nonexistent/path" 2>/dev/null; then
  echo "FAIL: Expected exit code 2 for missing folder"
  exit 1
fi

# Test 5: Unicode filename
cp "$FIXTURES_DIR/Röyksopp - Melody A.M..mp3" "$TEST_TMPDIR/" 2>/dev/null || true
if [[ -f "$TEST_TMPDIR/Röyksopp - Melody A.M..mp3" ]]; then
  output=$(bash "$SCRIPT" "$TEST_TMPDIR")
  file_count=$(echo "$output" | jq '.files | length')
  if [[ "$file_count" -ne 4 ]]; then
    echo "FAIL: Expected 4 files with unicode, got $file_count"
    exit 1
  fi
fi

# Test 6: No-metadata file is handled gracefully
cp "$FIXTURES_DIR/no-metadata.mp3" "$TEST_TMPDIR/" 2>/dev/null || true
output=$(bash "$SCRIPT" "$TEST_TMPDIR")
echo "$output" | jq . > /dev/null 2>&1 || { echo "FAIL: Invalid JSON output"; exit 1; }

echo "All inspect-metadata tests passed"
