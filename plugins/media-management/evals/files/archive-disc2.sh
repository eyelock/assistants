#!/usr/bin/env bash
# archive-media: disc 1 of Afterglow Live already on the NAS (MP3s and WAVs, release.json); disc 2 encoded by rip-cd in the temp work folder and imported to Apple Music.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
disc_done 1 archive
disc_done 2
snapshot
