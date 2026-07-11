#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/cleanup/scripts/cleanup-release.sh"

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Test 1: Loose audio files (single-track release, no ZIP) get archived to processed/
TRACK="Artist - Track"
touch "$TEST_TMPDIR/$TRACK.mp3"
touch "$TEST_TMPDIR/$TRACK.wav"
mkdir -p "$TEST_TMPDIR/$TRACK"

output=$(MEDIA_MGMT_PROCESSED="$TEST_TMPDIR/processed" bash "$SCRIPT" "$TEST_TMPDIR" "$TRACK")

audio_archived=$(echo "$output" | jq -r '.audio_files_archived')
folders_removed=$(echo "$output" | jq -r '.folders_removed')
[[ "$audio_archived" == "2" ]] || { echo "FAIL: expected audio_files_archived 2, got $audio_archived"; echo "$output"; exit 1; }
[[ "$folders_removed" == "1" ]] || { echo "FAIL: expected folders_removed 1, got $folders_removed"; echo "$output"; exit 1; }

[[ -f "$TEST_TMPDIR/processed/$TRACK.mp3" ]] || { echo "FAIL: mp3 not archived"; exit 1; }
[[ -f "$TEST_TMPDIR/processed/$TRACK.wav" ]] || { echo "FAIL: wav not archived"; exit 1; }
[[ ! -f "$TEST_TMPDIR/$TRACK.mp3" ]] || { echo "FAIL: original mp3 still in downloads"; exit 1; }
[[ ! -d "$TEST_TMPDIR/$TRACK" ]] || { echo "FAIL: extraction folder not removed"; exit 1; }

# Test 2: Nothing to clean up reports zeroes, not an error
output=$(MEDIA_MGMT_PROCESSED="$TEST_TMPDIR/processed" bash "$SCRIPT" "$TEST_TMPDIR" "Nonexistent Release")
audio_archived=$(echo "$output" | jq -r '.audio_files_archived')
zips_archived=$(echo "$output" | jq -r '.zips_archived')
[[ "$audio_archived" == "0" && "$zips_archived" == "0" ]] || {
  echo "FAIL: expected zero counts for nonexistent release"
  exit 1
}

echo "All cleanup-release tests passed"
