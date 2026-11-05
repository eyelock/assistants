#!/usr/bin/env bash
# audit-release: Afterglow Live imported cleanly by rip-cd (one album, both discs), except the files carry no embedded cover, so Apple Music shows its own guess.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
disc_done 1 archive
disc_done 2 archive
days_later
for f in "$LIBRARY_STORAGE/Night Drive/Afterglow Live/"*.mp3; do ffmpeg -v error -y -i "$f" -map 0:a -c copy -map_metadata 0 -id3v2_version 3 "$f.tmp.mp3" && mv "$f.tmp.mp3" "$f"; done
snapshot
