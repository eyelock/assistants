#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SET_SCRIPT="$PROJECT_ROOT/skills/manage-metadata/scripts/set-album-artist.sh"
CLEAR_SCRIPT="$PROJECT_ROOT/skills/manage-metadata/scripts/clear-album-artist.sh"
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

cp "$FIXTURES_DIR"/track*.mp3 "$TEST_TMPDIR/"

# First set an album artist so we can verify clearing it
bash "$SET_SCRIPT" "$TEST_TMPDIR" "Some Artist" > /dev/null

# Verify it was set
aa=$(ffprobe -v quiet -print_format json -show_format "$TEST_TMPDIR/track1.mp3" | jq -r '.format.tags.album_artist // ""')
if [[ "$aa" != "Some Artist" ]]; then
  echo "FAIL: Setup failed — album artist not set"
  exit 1
fi

# Test 1: Clear album artist
output=$(bash "$CLEAR_SCRIPT" "$TEST_TMPDIR")
updated=$(echo "$output" | jq '.updated')
if [[ "$updated" -ne 3 ]]; then
  echo "FAIL: Expected updated=3, got $updated"
  exit 1
fi

# Test 2: Verify cleared with ffprobe
aa=$(ffprobe -v quiet -print_format json -show_format "$TEST_TMPDIR/track1.mp3" | jq -r '.format.tags.album_artist // ""')
if [[ -n "$aa" ]]; then
  echo "FAIL: album_artist should be empty, got '$aa'"
  exit 1
fi

echo "All clear-album-artist tests passed"
