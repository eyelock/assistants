#!/usr/bin/env bash
# manage-metadata: Night Drive - Afterglow where track 3 is by Kora Lune and track 4 by Deep Room: three artists, so by the plugin's rule a compilation. No Album Artist is set.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
dir="$DOWNLOADS/Night Drive - Afterglow"
afterglow_mp3s "$dir"
mp3 "$dir/Night Drive - Afterglow - 03 Overpass.mp3" 6 420 "title=Overpass" "artist=Kora Lune" "album=Afterglow" "track=3" "genre=Electronic" "date=2026"
mp3 "$dir/Night Drive - Afterglow - 04 Last Train.mp3" 7 480 "title=Last Train" "artist=Deep Room" "album=Afterglow" "track=4" "genre=Electronic" "date=2026"
snapshot
