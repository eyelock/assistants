#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/select-release/scripts/inspect-audio-file.sh"

[[ -f "$FIXTURES_DIR/track1.mp3" ]] || {
  echo "SKIP: fixtures not found"
  exit 77
}

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Test 1: Loose MP3 file classifies as mp3, 1 track, source_type=file
output=$(bash "$SCRIPT" "$FIXTURES_DIR/track1.mp3")
type=$(echo "$output" | jq -r '.type')
tracks=$(echo "$output" | jq -r '.tracks')
source_type=$(echo "$output" | jq -r '.source_type')
[[ "$type" == "mp3" ]] || { echo "FAIL: expected type mp3, got $type"; exit 1; }
[[ "$tracks" == "1" ]] || { echo "FAIL: expected tracks 1, got $tracks"; exit 1; }
[[ "$source_type" == "file" ]] || { echo "FAIL: expected source_type file, got $source_type"; exit 1; }

# Test 2: Loose WAV file classifies as wav
cp "$FIXTURES_DIR/Test Artist - Test Album - 01 Track 1.wav" "$TEST_TMPDIR/Track.wav"
output=$(bash "$SCRIPT" "$TEST_TMPDIR/Track.wav")
type=$(echo "$output" | jq -r '.type')
[[ "$type" == "wav" ]] || { echo "FAIL: expected type wav, got $type"; exit 1; }

# Test 3: Unknown extension
touch "$TEST_TMPDIR/notes.txt"
output=$(bash "$SCRIPT" "$TEST_TMPDIR/notes.txt")
type=$(echo "$output" | jq -r '.type')
tracks=$(echo "$output" | jq -r '.tracks')
[[ "$type" == "unknown" ]] || { echo "FAIL: expected type unknown, got $type"; exit 1; }
[[ "$tracks" == "0" ]] || { echo "FAIL: expected tracks 0 for unknown, got $tracks"; exit 1; }

# Test 4: Missing file exits 2
if bash "$SCRIPT" "$TEST_TMPDIR/does-not-exist.mp3" 2>/dev/null; then
  echo "FAIL: expected non-zero exit for missing file"
  exit 1
fi

echo "All inspect-audio-file tests passed"
