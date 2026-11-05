#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/manage-metadata/scripts/update-track-count.sh"
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Setup: copy test MP3s
cp "$FIXTURES_DIR"/track*.mp3 "$TEST_TMPDIR/"

# Test 1: Updates track count
output=$(bash "$SCRIPT" "$TEST_TMPDIR")
updated=$(echo "$output" | jq '.updated')
total=$(echo "$output" | jq '.total')
if [[ "$updated" -ne 3 || "$total" -ne 3 ]]; then
  echo "FAIL: Expected updated=3, total=3, got updated=$updated, total=$total"
  exit 1
fi

# Test 2: Verify metadata was actually written
track_tag=$(ffprobe -v quiet -print_format json -show_format "$TEST_TMPDIR/track1.mp3" | jq -r '.format.tags.track // ""')
if [[ "$track_tag" != "1/3" ]]; then
  echo "FAIL: Expected track tag '1/3', got '$track_tag'"
  exit 1
fi

# Test 3: Idempotency — running again produces same result
output2=$(bash "$SCRIPT" "$TEST_TMPDIR")
updated2=$(echo "$output2" | jq '.updated')
if [[ "$updated2" -ne 3 ]]; then
  echo "FAIL: Idempotency check failed, updated=$updated2"
  exit 1
fi

# Test 4: Empty folder
empty_dir="$TEST_TMPDIR/empty"
mkdir -p "$empty_dir"
output=$(bash "$SCRIPT" "$empty_dir")
if [[ $(echo "$output" | jq '.total') -ne 0 ]]; then
  echo "FAIL: Expected total=0 for empty dir"
  exit 1
fi

# Test 5: Order follows the existing track numbers, not the filenames
order_dir="$TEST_TMPDIR/order"
mkdir -p "$order_dir"
cp "$FIXTURES_DIR/track3.mp3" "$order_dir/Band - Alpha.mp3"
cp "$FIXTURES_DIR/track1.mp3" "$order_dir/Band - Zulu.mp3"
cp "$FIXTURES_DIR/track2.mp3" "$order_dir/Band - Mike.mp3"
bash "$SCRIPT" "$order_dir" >/dev/null
zulu=$(ffprobe -v quiet -show_entries format_tags=track -of csv=p=0 "$order_dir/Band - Zulu.mp3")
alpha=$(ffprobe -v quiet -show_entries format_tags=track -of csv=p=0 "$order_dir/Band - Alpha.mp3")
[[ "$zulu" == "1/3" && "$alpha" == "3/3" ]] || { echo "FAIL: expected Zulu 1/3 and Alpha 3/3, got $zulu and $alpha"; exit 1; }

echo "All update-track-count tests passed"
