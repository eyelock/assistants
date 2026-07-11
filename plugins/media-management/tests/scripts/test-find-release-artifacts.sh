#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/cleanup/scripts/find-release-artifacts.sh"

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

RELEASE="Artist - Album"

# Test 1: Finds ZIPs, loose audio files, and extraction folders for a release
touch "$TEST_TMPDIR/$RELEASE.zip"
touch "$TEST_TMPDIR/$RELEASE-2.zip"
mkdir -p "$TEST_TMPDIR/$RELEASE" "$TEST_TMPDIR/$RELEASE-wav"

output=$(bash "$SCRIPT" "$TEST_TMPDIR" "$RELEASE")
zip_count=$(echo "$output" | jq '.zips | length')
folder_count=$(echo "$output" | jq '.folders | length')
[[ "$zip_count" -eq 2 ]] || { echo "FAIL: expected 2 zips, got $zip_count"; echo "$output"; exit 1; }
[[ "$folder_count" -eq 2 ]] || { echo "FAIL: expected 2 folders, got $folder_count"; echo "$output"; exit 1; }

rm -f "$TEST_TMPDIR/$RELEASE.zip" "$TEST_TMPDIR/$RELEASE-2.zip"
rm -rf "$TEST_TMPDIR/$RELEASE" "$TEST_TMPDIR/$RELEASE-wav"

# Test 2: Finds loose audio files for a single-track release (no ZIP)
TRACK="Artist - Track"
touch "$TEST_TMPDIR/$TRACK.mp3"
touch "$TEST_TMPDIR/$TRACK.wav"

output=$(bash "$SCRIPT" "$TEST_TMPDIR" "$TRACK")
audio_count=$(echo "$output" | jq '.audio_files | length')
zip_count=$(echo "$output" | jq '.zips | length')
[[ "$audio_count" -eq 2 ]] || { echo "FAIL: expected 2 audio_files, got $audio_count"; echo "$output"; exit 1; }
[[ "$zip_count" -eq 0 ]] || { echo "FAIL: expected 0 zips, got $zip_count"; exit 1; }

files=$(echo "$output" | jq -r '.audio_files[].file' | sort)
expected=$(printf '%s\n%s' "$TRACK.mp3" "$TRACK.wav" | sort)
[[ "$files" == "$expected" ]] || { echo "FAIL: unexpected audio_files: $files"; exit 1; }

rm -f "$TEST_TMPDIR/$TRACK.mp3" "$TEST_TMPDIR/$TRACK.wav"

# Test 3: Nothing found for an unrelated release name
output=$(bash "$SCRIPT" "$TEST_TMPDIR" "Nonexistent Release")
zip_count=$(echo "$output" | jq '.zips | length')
audio_count=$(echo "$output" | jq '.audio_files | length')
folder_count=$(echo "$output" | jq '.folders | length')
[[ "$zip_count" -eq 0 && "$audio_count" -eq 0 && "$folder_count" -eq 0 ]] || {
  echo "FAIL: expected nothing found for unrelated release"
  exit 1
}

echo "All find-release-artifacts tests passed"
