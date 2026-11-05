#!/usr/bin/env bash
# The quality-gate sandbox with the warning change, after a make check whose
# doclint cache now hides the warning (see quality-gate-repo.sh).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
SCENARIO=cached bash "$EVAL_FIXTURES/quality-gate-repo.sh"
