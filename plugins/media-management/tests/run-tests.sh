#!/usr/bin/env bash
# Run all test scripts and report pass/fail summary.
# Usage: run-tests.sh [--scripts-only] [--hooks-only] [--generate-fixtures]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
SKIP=0
FAILED_TESTS=()

SCRIPTS_ONLY=false
HOOKS_ONLY=false
GENERATE_FIXTURES=false

for arg in "$@"; do
  case "$arg" in
    --scripts-only) SCRIPTS_ONLY=true ;;
    --hooks-only) HOOKS_ONLY=true ;;
    --generate-fixtures) GENERATE_FIXTURES=true ;;
  esac
done

# Generate fixtures if requested or if they don't exist
if [[ "$GENERATE_FIXTURES" == true ]] || [[ ! -f "$SCRIPT_DIR/fixtures/track1.mp3" ]]; then
  echo "=== Generating test fixtures ==="
  bash "$SCRIPT_DIR/fixtures/generate-fixtures.sh" "$SCRIPT_DIR/fixtures"
  echo ""
fi

run_test() {
  local test_file="$1"
  local name
  name=$(basename "$test_file")
  printf "  %-45s " "$name"

  local rc=0
  bash "$test_file" "$SCRIPT_DIR/fixtures" "$PROJECT_ROOT" > /tmp/test-output-$$ 2>&1 || rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "PASS"
    ((PASS++)) || true
  elif [[ $rc -eq 77 ]]; then
    echo "SKIP"
    ((SKIP++)) || true
    sed 's/^/    | /' /tmp/test-output-$$
  else
    echo "FAIL"
    ((FAIL++)) || true
    FAILED_TESTS+=("$test_file")
    # Show failure output indented
    sed 's/^/    | /' /tmp/test-output-$$
  fi
  rm -f /tmp/test-output-$$
}

if [[ "$HOOKS_ONLY" != true ]]; then
  echo "=== Script Tests ==="
  for test_file in "$SCRIPT_DIR"/scripts/test-*.sh; do
    [[ -f "$test_file" ]] || continue
    run_test "$test_file"
  done
  echo ""
fi

if [[ "$SCRIPTS_ONLY" != true ]]; then
  echo "=== Hook Tests ==="
  for test_file in "$SCRIPT_DIR"/hooks/test-*.sh; do
    [[ -f "$test_file" ]] || continue
    run_test "$test_file"
  done
  echo ""
fi

echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Skipped: $SKIP"

if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
  echo ""
  echo "  Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "    - $t"
  done
fi

exit $((FAIL > 0 ? 1 : 0))
