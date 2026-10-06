#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/archive-media/scripts/archive-files.sh"

[[ -f "$FIXTURES_DIR/track1.mp3" ]] || {
  echo "SKIP: fixtures not found"
  exit 77
}

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Test 1: mp3 mode copies every MP3 and verifies the count
mkdir -p "$TEST_TMPDIR/library"
cp "$FIXTURES_DIR"/track*.mp3 "$TEST_TMPDIR/library/"
output=$(bash "$SCRIPT" mp3 "$TEST_TMPDIR/library" "$TEST_TMPDIR/nas/mp3" 2>/dev/null)
[[ $(echo "$output" | jq '.verified') == "true" ]] || { echo "FAIL: mp3 mode not verified"; echo "$output"; exit 1; }
[[ $(echo "$output" | jq '.dest_count') -eq 3 ]] || { echo "FAIL: expected 3 MP3s staged"; exit 1; }

# Test 2: wav mode renames vendor names, and stdout is exactly one JSON document
mkdir -p "$TEST_TMPDIR/wav"
cp "$FIXTURES_DIR"/*.wav "$TEST_TMPDIR/wav/"
output=$(bash "$SCRIPT" wav "$TEST_TMPDIR/wav" "$TEST_TMPDIR/nas/wav" 2>/dev/null)
[[ $(echo "$output" | jq -s 'length') -eq 1 ]] || { echo "FAIL: stdout is not a single JSON document"; echo "$output"; exit 1; }
[[ $(echo "$output" | jq '.renamed') == "true" ]] || { echo "FAIL: wav mode did not rename"; exit 1; }
[[ -f "$TEST_TMPDIR/nas/wav/01 Track 1.wav" ]] || { echo "FAIL: expected '01 Track 1.wav' on the NAS"; exit 1; }
[[ -f "$TEST_TMPDIR/wav/Test Artist - Test Album - 01 Track 1.wav" ]] || { echo "FAIL: source WAV was moved"; exit 1; }

# Test 3: a missing source folder fails with exit 2
rc=0
bash "$SCRIPT" mp3 "$TEST_TMPDIR/missing" "$TEST_TMPDIR/nas/x" >/dev/null 2>&1 || rc=$?
[[ $rc -eq 2 ]] || { echo "FAIL: expected exit 2 for a missing source, got $rc"; exit 1; }

echo "All archive-files tests passed"
