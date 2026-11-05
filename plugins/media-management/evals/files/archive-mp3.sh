#!/usr/bin/env bash
# archive-media: Night Drive - Afterglow imported into Apple Music (library copies named "01 Dusk.mp3", genre edited to Synthwave in Apple Music); the extracted vendor-named MP3s (genre Electronic) are still in Downloads.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
for i in 0 1 2 3; do
  mp3 "$LIBRARY_STORAGE/Night Drive/Afterglow/0$((i + 1)) ${AFTERGLOW_TITLES[$i]}.mp3" $((4 + i)) $((300 + 60 * i)) "title=${AFTERGLOW_TITLES[$i]}" "artist=Night Drive" "album=Afterglow" "track=$((i + 1))/4" "genre=Synthwave"
done
afterglow_mp3s "$DOWNLOADS/Night Drive - Afterglow"
snapshot
