#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/manage-metadata/scripts/set-album-artist.sh"
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

cp "$FIXTURES_DIR"/track*.mp3 "$TEST_TMPDIR/"

# Test 1: Set album artist
output=$(bash "$SCRIPT" "$TEST_TMPDIR" "DJ Shadow")
updated=$(echo "$output" | jq '.updated')
aa=$(echo "$output" | jq -r '.album_artist')
if [[ "$updated" -ne 3 || "$aa" != "DJ Shadow" ]]; then
  echo "FAIL: Expected updated=3 album_artist='DJ Shadow', got updated=$updated aa='$aa'"
  exit 1
fi

# Test 2: Verify with ffprobe
actual_aa=$(ffprobe -v quiet -print_format json -show_format "$TEST_TMPDIR/track1.mp3" | jq -r '.format.tags.album_artist // ""')
if [[ "$actual_aa" != "DJ Shadow" ]]; then
  echo "FAIL: ffprobe shows album_artist='$actual_aa', expected 'DJ Shadow'"
  exit 1
fi

# Test 3: Idempotency
output2=$(bash "$SCRIPT" "$TEST_TMPDIR" "DJ Shadow")
updated2=$(echo "$output2" | jq '.updated')
if [[ "$updated2" -ne 3 ]]; then
  echo "FAIL: Idempotency failed"
  exit 1
fi

echo "All set-album-artist tests passed"
