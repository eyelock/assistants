#!/usr/bin/env bash
# manage-metadata: Night Drive - Afterglow extracted in Downloads with the genre blank on every track.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
afterglow_mp3s "$DOWNLOADS/Night Drive - Afterglow" "genre="
snapshot
