#!/usr/bin/env bash
# rip-cd: disc 1 finished days ago (in Apple Music and on the NAS with its release.json); the temp work folder is gone; disc 2 is now in the drive.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
disc_done 1 archive
days_later
insert_disc 2
snapshot
