#!/usr/bin/env bash
# manage-metadata: Night Drive - Afterglow extracted in Downloads with two real problems: Album Artist is set on a single-artist album, and track 3 has no genre.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
dir="$DOWNLOADS/Night Drive - Afterglow"
afterglow_mp3s "$dir" "album_artist=Night Drive"
mp3 "$dir/Night Drive - Afterglow - 03 Overpass.mp3" 6 420 "title=Overpass" "artist=Night Drive" "album=Afterglow" "track=3" "album_artist=Night Drive" "date=2026"
snapshot
