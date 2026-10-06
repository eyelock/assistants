#!/usr/bin/env bash
# import-to-apple-music: the WAV side of Night Drive - Afterglow extracted in Downloads (Night Drive - Afterglow-wav); the MP3s are already in the Apple Music library.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
afterglow_wavs "$DOWNLOADS/Night Drive - Afterglow-wav"
afterglow_mp3s "$LIBRARY_STORAGE/Night Drive/Afterglow"
snapshot
