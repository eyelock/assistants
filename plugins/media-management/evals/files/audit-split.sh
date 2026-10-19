#!/usr/bin/env bash
# audit-release: Afterglow Live as Apple Music's own CD import left it: split into 'Afterglow Live' and 'Afterglow Live [Disc 2]', no Album Artist, a live suffix on every title, no embedded cover, nothing on the NAS. No disc in the drive.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs none
half_done_import
snapshot
