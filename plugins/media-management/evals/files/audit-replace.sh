#!/usr/bin/env bash
# audit-release: the split, half-done Afterglow Live import (as in audit-split), with disc 1 in the drive for a re-rip.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
half_done_import
snapshot
