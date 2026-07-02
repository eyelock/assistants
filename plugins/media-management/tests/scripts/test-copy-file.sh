#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/process-album/scripts/copy-file.sh"

[[ -f "$FIXTURES_DIR/track1.mp3" ]] || {
  echo "SKIP: fixtures not found"
  exit 77
}

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Test 1: Copies file into a named subfolder and reports it
output=$(bash "$SCRIPT" "$FIXTURES_DIR/track1.mp3" "$TEST_TMPDIR/Solo Track")
[[ -f "$TEST_TMPDIR/Solo Track/track1.mp3" ]] || { echo "FAIL: file not copied"; exit 1; }
audio_files=$(echo "$output" | jq -r '.audio_files')
[[ "$audio_files" == "1" ]] || { echo "FAIL: expected audio_files 1, got $audio_files"; exit 1; }

# Test 2: Original file is untouched (copy, not move)
[[ -f "$FIXTURES_DIR/track1.mp3" ]] || { echo "FAIL: source file was removed"; exit 1; }

# Test 3: Refuses to copy directly to Downloads-like root
if bash "$SCRIPT" "$FIXTURES_DIR/track1.mp3" "$HOME/Downloads" 2>/dev/null; then
  echo "FAIL: expected refusal to copy to Downloads root"
  exit 1
fi

# Test 4: Missing source file exits non-zero
if bash "$SCRIPT" "$TEST_TMPDIR/does-not-exist.mp3" "$TEST_TMPDIR/Dest" 2>/dev/null; then
  echo "FAIL: expected non-zero exit for missing source"
  exit 1
fi

echo "All copy-file tests passed"
