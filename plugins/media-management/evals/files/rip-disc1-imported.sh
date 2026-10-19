#!/usr/bin/env bash
# rip-cd: disc 1 ripped, verified, encoded and imported to Apple Music earlier in the session (2-CD edition, genre Electronic); the user has not yet confirmed the import, so nothing is on the NAS.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
disc_done 1
snapshot
