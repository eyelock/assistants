#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/manage-metadata/scripts/update-genre.sh"
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

cp "$FIXTURES_DIR"/track*.mp3 "$TEST_TMPDIR/"

# Test 1: Set genre
output=$(bash "$SCRIPT" "$TEST_TMPDIR" "Ambient")
updated=$(echo "$output" | jq '.updated')
genre=$(echo "$output" | jq -r '.genre')
if [[ "$updated" -ne 3 || "$genre" != "Ambient" ]]; then
  echo "FAIL: Expected updated=3 genre=Ambient, got updated=$updated genre=$genre"
  exit 1
fi

# Test 2: Verify with ffprobe
actual_genre=$(ffprobe -v quiet -print_format json -show_format "$TEST_TMPDIR/track1.mp3" | jq -r '.format.tags.genre // ""')
if [[ "$actual_genre" != "Ambient" ]]; then
  echo "FAIL: ffprobe shows genre='$actual_genre', expected 'Ambient'"
  exit 1
fi

# Test 3: Missing args
if bash "$SCRIPT" "$TEST_TMPDIR" 2>/dev/null; then
  echo "FAIL: Expected error for missing genre arg"
  exit 1
fi

echo "All update-genre tests passed"
