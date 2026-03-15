#!/usr/bin/env bash
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
SCRIPT="$PROJECT_ROOT/skills/archive-media/scripts/rename-wav-files.sh"
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Setup: copy WAV files with vendor naming
cp "$FIXTURES_DIR"/Test\ Artist\ -\ Test\ Album\ -\ 0*.wav "$TEST_TMPDIR/" 2>/dev/null || {
  echo "SKIP: WAV fixtures not found"
  exit 77
}

# Test 1: Rename from vendor format
output=$(bash "$SCRIPT" "$TEST_TMPDIR")
renamed_count=$(echo "$output" | jq '.renamed | length')
if [[ "$renamed_count" -ne 3 ]]; then
  echo "FAIL: Expected 3 renames, got $renamed_count"
  exit 1
fi

# Test 2: Verify new filenames exist
for i in 1 2 3; do
  padded=$(printf "%02d" "$i")
  if [[ ! -f "$TEST_TMPDIR/${padded} Track ${i}.wav" ]]; then
    echo "FAIL: Expected file '${padded} Track ${i}.wav' not found"
    ls -la "$TEST_TMPDIR/"
    exit 1
  fi
done

# Test 3: Verify old filenames are gone
for f in "$TEST_TMPDIR"/Test\ Artist*.wav; do
  if [[ -f "$f" ]]; then
    echo "FAIL: Old file still exists: $f"
    exit 1
  fi
done

# Test 4: Idempotency — running again produces no changes
output2=$(bash "$SCRIPT" "$TEST_TMPDIR")
renamed_count2=$(echo "$output2" | jq '.renamed | length')
if [[ "$renamed_count2" -ne 0 ]]; then
  echo "FAIL: Idempotency failed — got $renamed_count2 renames on second run"
  exit 1
fi

# Test 5: Empty folder
empty_dir="$TEST_TMPDIR/empty"
mkdir -p "$empty_dir"
output=$(bash "$SCRIPT" "$empty_dir")
if [[ $(echo "$output" | jq '.renamed | length') -ne 0 ]]; then
  echo "FAIL: Expected 0 renames for empty dir"
  exit 1
fi

echo "All rename-wav-files tests passed"
