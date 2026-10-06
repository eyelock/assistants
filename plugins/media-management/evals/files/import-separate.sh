#!/usr/bin/env bash
# import-to-apple-music: Summer Sampler was imported without an Album Artist, so Apple Music filed it under each artist (four folders in the library). The extracted MP3s are still in Downloads.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
sampler_mp3s "$DOWNLOADS/Summer Sampler"
for i in 0 1 2 3; do
  mp3 "$LIBRARY_STORAGE/${SAMPLER_ARTISTS[$i]}/Summer Sampler/0$((i + 1)) ${SAMPLER_TITLES[$i]}.mp3" $((4 + i)) $((400 + 50 * i)) "title=${SAMPLER_TITLES[$i]}" "artist=${SAMPLER_ARTISTS[$i]}" "album=Summer Sampler" "track=$((i + 1))" "genre=House"
done
snapshot
