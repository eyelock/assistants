#!/usr/bin/env bash
# The dev-debug sandbox with the router bug (see dev-debug-setup.sh).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
SCENARIO=router bash "$EVAL_FIXTURES/dev-debug-setup.sh"
