#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/manage-metadata/scripts/set-compilation.sh"
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

cp "$FIXTURES_DIR"/track*.mp3 "$TEST_TMPDIR/"

# Test 1: Set compilation = true
output=$(bash "$SCRIPT" "$TEST_TMPDIR" "true")
updated=$(echo "$output" | jq '.updated')
comp=$(echo "$output" | jq '.compilation')
if [[ "$updated" -ne 3 || "$comp" != "true" ]]; then
  echo "FAIL: Expected updated=3 compilation=true, got updated=$updated compilation=$comp"
  exit 1
fi

# Test 2: Verify compilation flag and album artist with ffprobe
meta=$(ffprobe -v quiet -print_format json -show_format "$TEST_TMPDIR/track1.mp3")
comp_val=$(echo "$meta" | jq -r '.format.tags.compilation // ""')
aa_val=$(echo "$meta" | jq -r '.format.tags.album_artist // ""')
if [[ "$comp_val" != "1" ]]; then
  echo "FAIL: Expected compilation=1, got '$comp_val'"
  exit 1
fi
if [[ "$aa_val" != "Various Artists" ]]; then
  echo "FAIL: Expected album_artist='Various Artists', got '$aa_val'"
  exit 1
fi

# Test 3: Set compilation = false
output=$(bash "$SCRIPT" "$TEST_TMPDIR" "false")
comp=$(echo "$output" | jq '.compilation')
if [[ "$comp" != "false" ]]; then
  echo "FAIL: Expected compilation=false, got $comp"
  exit 1
fi

# Test 4: Verify cleared
meta=$(ffprobe -v quiet -print_format json -show_format "$TEST_TMPDIR/track1.mp3")
comp_val=$(echo "$meta" | jq -r '.format.tags.compilation // ""')
aa_val=$(echo "$meta" | jq -r '.format.tags.album_artist // ""')
if [[ "$comp_val" != "0" ]]; then
  echo "FAIL: Expected compilation=0, got '$comp_val'"
  exit 1
fi
if [[ -n "$aa_val" ]]; then
  echo "FAIL: Expected empty album_artist, got '$aa_val'"
  exit 1
fi

echo "All set-compilation tests passed"
