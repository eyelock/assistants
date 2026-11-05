#!/usr/bin/env bash
# The dev-debug sandbox with the stale bug (see dev-debug-setup.sh).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
SCENARIO=stale bash "$EVAL_FIXTURES/dev-debug-setup.sh"
