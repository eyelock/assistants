#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/select-release/scripts/find-releases.sh"

[[ -f "$FIXTURES_DIR/track1.mp3" ]] || {
  echo "SKIP: fixtures not found"
  exit 77
}

command -v zip >/dev/null 2>&1 || {
  echo "SKIP: zip command not available"
  exit 77
}

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Test 1: A loose single-track MP3+WAV pair (no ZIP) is found and paired
cp "$FIXTURES_DIR/track1.mp3" "$TEST_TMPDIR/Solo Artist - Solo Track.mp3"
cp "$FIXTURES_DIR/Test Artist - Test Album - 01 Track 1.wav" "$TEST_TMPDIR/Solo Artist - Solo Track.wav"

output=$(bash "$SCRIPT" "$TEST_TMPDIR")
release_count=$(echo "$output" | jq '.releases | length')
[[ "$release_count" -eq 1 ]] || { echo "FAIL: expected 1 release, got $release_count"; echo "$output"; exit 1; }

name=$(echo "$output" | jq -r '.releases[0].name')
[[ "$name" == "Solo Artist - Solo Track" ]] || { echo "FAIL: unexpected release name: $name"; exit 1; }

mp3_source_type=$(echo "$output" | jq -r '.releases[0].mp3_source.source_type')
wav_source_type=$(echo "$output" | jq -r '.releases[0].wav_source.source_type')
[[ "$mp3_source_type" == "file" ]] || { echo "FAIL: expected mp3_source.source_type=file, got $mp3_source_type"; exit 1; }
[[ "$wav_source_type" == "file" ]] || { echo "FAIL: expected wav_source.source_type=file, got $wav_source_type"; exit 1; }

rm -f "$TEST_TMPDIR"/*.mp3 "$TEST_TMPDIR"/*.wav

# Test 2: A ZIP-based release still pairs correctly and reports source_type=zip
(cd "$FIXTURES_DIR" && zip -q "$TEST_TMPDIR/Artist - Album.zip" track1.mp3 track2.mp3)
(cd "$FIXTURES_DIR" && zip -q "$TEST_TMPDIR/Artist - Album-2.zip" "Test Artist - Test Album - 01 Track 1.wav" "Test Artist - Test Album - 02 Track 2.wav")

output=$(bash "$SCRIPT" "$TEST_TMPDIR")
release_count=$(echo "$output" | jq '.releases | length')
[[ "$release_count" -eq 1 ]] || { echo "FAIL: expected 1 zip release, got $release_count"; echo "$output"; exit 1; }

mp3_source_type=$(echo "$output" | jq -r '.releases[0].mp3_source.source_type')
[[ "$mp3_source_type" == "zip" ]] || { echo "FAIL: expected mp3_source.source_type=zip, got $mp3_source_type"; exit 1; }

rm -f "$TEST_TMPDIR"/*.zip

# Test 3: A solo loose MP3 with no WAV pair reports wav_source as null
cp "$FIXTURES_DIR/track1.mp3" "$TEST_TMPDIR/Solo No Wav.mp3"
output=$(bash "$SCRIPT" "$TEST_TMPDIR")
wav_source=$(echo "$output" | jq -r '.releases[0].wav_source')
[[ "$wav_source" == "null" ]] || { echo "FAIL: expected null wav_source, got $wav_source"; exit 1; }
rm -f "$TEST_TMPDIR"/*.mp3

# Test 4: Empty folder reports total_sources=0 and no releases
output=$(bash "$SCRIPT" "$TEST_TMPDIR")
total_sources=$(echo "$output" | jq -r '.total_sources')
release_count=$(echo "$output" | jq '.releases | length')
[[ "$total_sources" -eq 0 ]] || { echo "FAIL: expected total_sources 0, got $total_sources"; exit 1; }
[[ "$release_count" -eq 0 ]] || { echo "FAIL: expected 0 releases for empty folder, got $release_count"; exit 1; }

echo "All find-releases tests passed"
