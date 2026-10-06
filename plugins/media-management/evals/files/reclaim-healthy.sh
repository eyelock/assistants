#!/usr/bin/env bash
# reclaim-space: Sync Library is on; the stub library has 12,000 tracks, most cloud-backed, 1,800 in the Crates folder's playlists, 900 with a DJ grouping and 350 WAVs.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_music_stub
snapshot
