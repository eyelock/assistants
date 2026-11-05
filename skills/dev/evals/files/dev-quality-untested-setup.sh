#!/usr/bin/env bash
# The dev-quality sandbox with the untested change (see dev-quality-repo.sh).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
SCENARIO=untested bash "$EVAL_FIXTURES/dev-quality-repo.sh"
