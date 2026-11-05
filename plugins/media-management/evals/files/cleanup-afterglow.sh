#!/usr/bin/env bash
# cleanup: Night Drive - Afterglow fully processed (both ZIPs and both extraction folders still in Downloads, MP3s and WAVs on the NAS), next to a different, unprocessed release whose name starts the same (Night Drive - Afterglow (Remixes).zip) and unrelated clutter.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
afterglow_zips
afterglow_remixes_zip
clutter
afterglow_mp3s "$DOWNLOADS/Night Drive - Afterglow"
afterglow_wavs "$DOWNLOADS/Night Drive - Afterglow-wav"
for i in 0 1 2 3; do
  cp "$DOWNLOADS/Night Drive - Afterglow/Night Drive - Afterglow - 0$((i + 1)) ${AFTERGLOW_TITLES[$i]}.mp3" "$SANDBOX/.eval/t.mp3"
  mkdir -p "$ARCHIVE_WORKDIR/to_nas/mp3/Night Drive/Afterglow" "$ARCHIVE_WORKDIR/to_nas/wav/Night Drive/Afterglow"
  mv "$SANDBOX/.eval/t.mp3" "$ARCHIVE_WORKDIR/to_nas/mp3/Night Drive/Afterglow/0$((i + 1)) ${AFTERGLOW_TITLES[$i]}.mp3"
  cp "$DOWNLOADS/Night Drive - Afterglow-wav/Night Drive - Afterglow - 0$((i + 1)) ${AFTERGLOW_TITLES[$i]}.wav" "$ARCHIVE_WORKDIR/to_nas/wav/Night Drive/Afterglow/0$((i + 1)) ${AFTERGLOW_TITLES[$i]}.wav"
done
snapshot
