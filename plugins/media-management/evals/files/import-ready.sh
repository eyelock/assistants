#!/usr/bin/env bash
# import-to-apple-music: Night Drive - Afterglow extracted in Downloads with final tags, its cover.jpg beside the MP3s; the auto-import folder is empty.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
dir="$DOWNLOADS/Night Drive - Afterglow"
afterglow_mp3s "$dir"
cover "$dir/cover.jpg"
snapshot
