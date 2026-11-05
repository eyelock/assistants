#!/usr/bin/env bash
# The dev-quality sandbox with the red change (see dev-quality-repo.sh).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
SCENARIO=red bash "$EVAL_FIXTURES/dev-quality-repo.sh"
