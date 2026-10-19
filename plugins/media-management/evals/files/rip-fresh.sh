#!/usr/bin/env bash
# rip-cd: disc 1 of Night Drive - Afterglow Live in the drive, nothing of it imported yet. The disc belongs to two editions (a DVD + 2 CD box, and a 2-CD set).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
snapshot
