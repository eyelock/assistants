#!/usr/bin/env bash
# select-release: Night Drive - Afterglow zipped by macOS Finder: each ZIP holds the album folder plus a __MACOSX/ tree of "._" forks named like the tracks and a .DS_Store, so a plain listing shows twice the tracks. The WAV ZIP comes first by name ("Afterglow.zip"), the MP3 ZIP is "-2".
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
gen="$SANDBOX/.eval/gen"
rm -rf "$gen" && mkdir -p "$gen/mp3/Night Drive - Afterglow" "$gen/wav/Night Drive - Afterglow"
afterglow_mp3s "$gen/mp3/Night Drive - Afterglow"
afterglow_wavs "$gen/wav/Night Drive - Afterglow"
for kind in mp3 wav; do
  (cd "$gen/$kind" && mkdir -p "__MACOSX/Night Drive - Afterglow" && printf 'ds' >"Night Drive - Afterglow/.DS_Store")
  for f in "$gen/$kind/Night Drive - Afterglow/"*."$kind"; do
    printf 'fork' >"$gen/$kind/__MACOSX/Night Drive - Afterglow/._$(basename "$f")"
  done
done
(cd "$gen/wav" && zip -q -r -X "$DOWNLOADS/Night Drive - Afterglow.zip" .) || exit 3
(cd "$gen/mp3" && zip -q -r -X "$DOWNLOADS/Night Drive - Afterglow-2.zip" .) || exit 3
snapshot
