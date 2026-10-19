#!/usr/bin/env bash
# setup: every required path configured in config.json; no optional key set.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
snapshot
