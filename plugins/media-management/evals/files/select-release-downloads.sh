#!/usr/bin/env bash
# select-release: a fresh Bandcamp order (Night Drive - Afterglow, MP3 and WAV ZIPs), a one-track purchase as loose files (Kora Lune - Tidal), unrelated clutter, and a ZIP processed long ago in Downloads/processed/.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
afterglow_zips
tidal_single
clutter
mkdir -p "$DOWNLOADS/processed"
mp3 "$SANDBOX/.eval/gen/old/01 Old Song.mp3" 3 300 "title=Old Song" "artist=Old Band"
zipup "$DOWNLOADS/processed/Old Band - Old Album.zip" "$SANDBOX/.eval/gen/old"
snapshot
