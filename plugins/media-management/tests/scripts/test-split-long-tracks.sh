#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/split-long-tracks/scripts/split-long-tracks.sh"
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Test 1: Short track is skipped (not split)
cp "$FIXTURES_DIR/track1.mp3" "$TEST_TMPDIR/"
output=$(bash "$SCRIPT" "$TEST_TMPDIR" 78)
splits=$(echo "$output" | jq '.splits | length')
skipped=$(echo "$output" | jq '.skipped | length')
if [[ "$splits" -ne 0 ]]; then
  echo "FAIL: Short track should not be split, got $splits splits"
  exit 1
fi
if [[ "$skipped" -ne 1 ]]; then
  echo "FAIL: Expected 1 skipped, got $skipped"
  exit 1
fi

# Test 2: Long track is split (use very low max to force split)
rm -f "$TEST_TMPDIR"/*
cp "$FIXTURES_DIR/long-track.mp3" "$TEST_TMPDIR/"

# The long track is ~15s. Set max to 0.1 minutes (6s) to force a split
output=$(bash "$SCRIPT" "$TEST_TMPDIR" "0.1")
splits=$(echo "$output" | jq '.splits | length')
if [[ "$splits" -lt 1 ]]; then
  echo "FAIL: Expected at least 1 split, got $splits"
  exit 1
fi

# Test 3: Original file should be removed
if [[ -f "$TEST_TMPDIR/long-track.mp3" ]]; then
  echo "FAIL: Original file should be removed after split"
  exit 1
fi

# Test 4: Split files should exist
split_files=$(find "$TEST_TMPDIR" -iname '*.mp3' -type f | wc -l | tr -d ' ')
if [[ "$split_files" -lt 2 ]]; then
  echo "FAIL: Expected at least 2 split files, found $split_files"
  exit 1
fi

# Test 5: Output is valid JSON
echo "$output" | jq . > /dev/null 2>&1 || {
  echo "FAIL: Output is not valid JSON"
  exit 1
}

# Test 6: Missing path
if bash "$SCRIPT" "/nonexistent" 2>/dev/null; then
  echo "FAIL: Expected error for missing path"
  exit 1
fi

echo "All split-long-tracks tests passed"
