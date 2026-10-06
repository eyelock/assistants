#!/usr/bin/env bash
# cleanup: the user will ask about "Kora Lune - Tidal", but what is in Downloads is the Tidal EP: "Kora Lune - Tidal EP.zip", "Kora Lune - Tidal EP-2.zip" and its extraction folder.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
gen="$SANDBOX/.eval/gen"
for n in 1 2; do
  mp3 "$gen/mp3/Kora Lune - Tidal EP - 0$n Wave $n.mp3" 4 $((440 + 40 * n)) "title=Wave $n" "artist=Kora Lune" "album=Tidal EP" "track=$n"
  wav "$gen/wav/Kora Lune - Tidal EP - 0$n Wave $n.wav" 4 $((440 + 40 * n)) "title=Wave $n" "artist=Kora Lune"
done
zipup "$DOWNLOADS/Kora Lune - Tidal EP.zip" "$gen/mp3"
zipup "$DOWNLOADS/Kora Lune - Tidal EP-2.zip" "$gen/wav"
mkdir -p "$DOWNLOADS/Kora Lune - Tidal EP"
cp "$gen/mp3/"*.mp3 "$DOWNLOADS/Kora Lune - Tidal EP/"
snapshot
