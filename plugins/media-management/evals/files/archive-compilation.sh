#!/usr/bin/env bash
# archive-media: Summer Sampler imported as a compilation, so Apple Music filed it under Various Artists/Summer Sampler; each track keeps its own artist.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
for i in 0 1 2 3; do
  mp3 "$LIBRARY_STORAGE/Various Artists/Summer Sampler/0$((i + 1)) ${SAMPLER_TITLES[$i]}.mp3" $((4 + i)) $((400 + 50 * i)) "title=${SAMPLER_TITLES[$i]}" "artist=${SAMPLER_ARTISTS[$i]}" "album=Summer Sampler" "album_artist=Various Artists" "compilation=1" "track=$((i + 1))/4" "genre=House"
done
snapshot
