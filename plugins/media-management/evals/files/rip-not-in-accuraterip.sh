#!/usr/bin/env bash
# rip-cd: disc 1 in the drive; nobody has submitted this pressing to AccurateRip (the lookup returns 404).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
rm -f "$SANDBOX"/.eval/web/dBAR-*.bin
snapshot
