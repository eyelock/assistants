#!/usr/bin/env bash
# shellcheck shell=bash
# Shared by the CD and audit tests: build an eval sandbox (evals/files/sandbox.sh)
# in a temp directory and run the plugin's scripts against it, with its stubs
# (drive, web, Apple Music) first on PATH. Source it, then call:
#
#   sandbox_build <builder>...   e.g. sandbox_build world "install_cd_stubs 1"
#   run_in_sandbox <cmd>...      run a command inside it, with its env
#   fail <message>               print FAIL and exit 1
#
# Sets SB (the sandbox), SKILLS, and TEST_TMPDIR (removed on exit).

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT
SB="$TEST_TMPDIR/sandbox"
SKILLS="$(cd "${PROJECT_ROOT:-.}" && pwd)/skills"
export SKILLS # read by the tests that source this
FIXTURES="$(cd "${PROJECT_ROOT:-.}" && pwd)/evals/files"

fail() {
  echo "FAIL: $*"
  exit 1
}

sandbox_build() {
  rm -rf "$SB"
  mkdir -p "$SB/.eval/bin"
  (
    cd "$SB" || exit 3
    export EVAL_FIXTURES="$FIXTURES" EVAL_BIN="$SB/.eval/bin" EVAL_STUB_LOG="$SB/.eval/stub-calls.log"
    : >"$EVAL_STUB_LOG"
    # shellcheck source=/dev/null
    source "$EVAL_FIXTURES/sandbox.sh"
    for builder in "$@"; do eval "$builder"; done
  ) >"$TEST_TMPDIR/build.log" 2>&1 || {
    cat "$TEST_TMPDIR/build.log"
    fail "sandbox build failed: $*"
  }
}

run_in_sandbox() {
  (
    cd "$SB" || exit 3
    PATH="$SB/.eval/bin:$PATH" MEDIA_MGMT_CONFIG_PATH="$SB/config/media-management.json" \
      EVAL_STUB_LOG="$SB/.eval/stub-calls.log" HOME="$SB/home" "$@"
  )
}
