#!/usr/bin/env bash
# process-album: a fresh purchase of Night Drive - Afterglow (MP3 ZIP and WAV ZIP) in Downloads, with unrelated clutter; Apple Music and the NAS are empty.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
afterglow_zips
clutter
snapshot
