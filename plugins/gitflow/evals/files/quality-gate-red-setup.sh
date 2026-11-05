#!/usr/bin/env bash
# The quality-gate sandbox with the red change (see quality-gate-repo.sh).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
SCENARIO=red bash "$EVAL_FIXTURES/quality-gate-repo.sh"
