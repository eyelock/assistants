#!/usr/bin/env bash
# import-to-apple-music: disc 1 of Afterglow Live encoded by rip-cd, MP3s ready in the temp work folder, not yet in Apple Music.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
disc_done 1 encoded
snapshot
