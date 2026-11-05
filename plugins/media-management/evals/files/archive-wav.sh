#!/usr/bin/env bash
# archive-media: the WAVs of Night Drive - Afterglow extracted in Downloads with vendor names; its MP3s are already staged on the NAS.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
afterglow_wavs "$DOWNLOADS/Night Drive - Afterglow-wav"
for i in 0 1 2 3; do
  mp3 "$ARCHIVE_WORKDIR/to_nas/mp3/Night Drive/Afterglow/0$((i + 1)) ${AFTERGLOW_TITLES[$i]}.mp3" $((4 + i)) $((300 + 60 * i)) "title=${AFTERGLOW_TITLES[$i]}" "artist=Night Drive" "album=Afterglow" "track=$((i + 1))/4" "genre=Electronic"
done
snapshot
