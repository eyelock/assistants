#!/usr/bin/env bash
# The quality-gate sandbox with the warning change (see quality-gate-repo.sh).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
SCENARIO=warning bash "$EVAL_FIXTURES/quality-gate-repo.sh"
