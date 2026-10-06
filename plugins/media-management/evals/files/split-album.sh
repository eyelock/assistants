#!/usr/bin/env bash
# split-long-tracks: DJ Aster - Live at Dawn extracted in Downloads: intro, an 80-minute live mix (one 2-second silence at 39:00), outro.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
long_set "$DOWNLOADS/DJ Aster - Live at Dawn"
snapshot
