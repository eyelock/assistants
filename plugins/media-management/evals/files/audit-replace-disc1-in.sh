#!/usr/bin/env bash
# audit-release: replacing the split, half-done Afterglow Live import is under way: the old 6 tracks were snapshotted to the temp work folder, then disc 1 was re-ripped and imported (so Apple Music holds the old 6 and the new disc 1). The user has not yet said the new disc 1 looks right; disc 2 is not re-ripped.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
half_done_import
W="$WORK_BASE/audit-Night Drive - Afterglow Live"
mkdir -p "$W"
plugin audit-release/scripts/music-tracks.sh --artist "Night Drive" --album "Afterglow Live" \
  --album "Afterglow Live [Disc 2]" --out "$W/old-tracks.json"
disc_done 1
snapshot
