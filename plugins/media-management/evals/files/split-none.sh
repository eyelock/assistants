#!/usr/bin/env bash
# split-long-tracks: Night Drive - Afterglow extracted in Downloads; every track is a few seconds long.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
afterglow_mp3s "$DOWNLOADS/Night Drive - Afterglow"
snapshot
