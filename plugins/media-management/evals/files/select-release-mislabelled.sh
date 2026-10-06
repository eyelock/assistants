#!/usr/bin/env bash
# select-release: ZIPs whose names lie. "Deep Room - Signals.zip" holds the WAVs and "-2.zip" the MP3s (the reverse of the usual order), "Deep Room - Signals (1).zip" is the WAV ZIP downloaded twice, and "Aster - Glasshouse EP (pre-order).zip" is an MP3-only pre-order with no WAV ZIP.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
gen="$SANDBOX/.eval/gen"
for n in 1 2 3; do
  wav "$gen/wav/Deep Room - Signals - 0$n Signal $n.wav" 4 $((300 + 40 * n)) "title=Signal $n" "artist=Deep Room"
  mp3 "$gen/mp3/Deep Room - Signals - 0$n Signal $n.mp3" 4 $((300 + 40 * n)) "title=Signal $n" "artist=Deep Room" "album=Signals" "track=$n"
done
zipup "$DOWNLOADS/Deep Room - Signals.zip" "$gen/wav"
cp "$DOWNLOADS/Deep Room - Signals.zip" "$DOWNLOADS/Deep Room - Signals (1).zip"
zipup "$DOWNLOADS/Deep Room - Signals-2.zip" "$gen/mp3"
for n in 1 2; do
  mp3 "$gen/ep/Aster - Glasshouse EP - 0$n Pane $n.mp3" 4 $((500 + 40 * n)) "title=Pane $n" "artist=Aster" "album=Glasshouse EP" "track=$n"
done
zipup "$DOWNLOADS/Aster - Glasshouse EP (pre-order).zip" "$gen/ep"
snapshot
