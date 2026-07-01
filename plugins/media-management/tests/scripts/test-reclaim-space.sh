#!/usr/bin/env bash
set -euo pipefail

# reclaim-space talks to the Apple Music app, which cannot run in CI. These tests
# cover only the Music-independent paths: --help and argument validation, which
# return before any osascript call.

# shellcheck disable=SC2034  # FIXTURES_DIR unused (no audio fixtures needed)
FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
AUDIT="$PROJECT_ROOT/skills/reclaim-space/scripts/audit-library.sh"
BUILD="$PROJECT_ROOT/skills/reclaim-space/scripts/build-offload-playlist.sh"

fail() { echo "FAIL: $1"; exit 1; }

# Test 1: audit --help succeeds and prints usage
out=$(bash "$AUDIT" --help) || fail "audit --help exited non-zero"
echo "$out" | grep -q "Usage: audit-library.sh" || fail "audit --help missing usage banner"

# Test 2: build --help succeeds and prints usage
out=$(bash "$BUILD" --help) || fail "build --help exited non-zero"
echo "$out" | grep -q "Usage: build-offload-playlist.sh" || fail "build --help missing usage banner"

# Test 3: unknown argument is rejected with exit 1
rc=0; bash "$AUDIT" --bogus >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]] || fail "audit unknown arg should exit 1, got $rc"

# Test 4: flag missing its value is rejected with exit 1
rc=0; bash "$BUILD" --keep-folder >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]] || fail "build --keep-folder with no value should exit 1, got $rc"

rc=0; bash "$BUILD" --playlist >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]] || fail "build --playlist with no value should exit 1, got $rc"

# Test 5: on a host without osascript, scripts report an environment error (2)
if ! command -v osascript >/dev/null 2>&1; then
  rc=0; bash "$AUDIT" >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 2 ]] || fail "audit without osascript should exit 2, got $rc"
fi

echo "All reclaim-space tests passed"
