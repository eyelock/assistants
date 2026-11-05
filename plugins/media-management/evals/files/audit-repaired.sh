#!/usr/bin/env bash
# audit-release: the split Afterglow Live import repaired earlier in the session (merged, Album Artist set, suffix stripped, cover embedded); the repair's plan is still in the temp work folder.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs none
half_done_import
W="$WORK_BASE/audit-Night Drive - Afterglow Live"; mkdir -p "$W"
plugin rip-cd/scripts/make-release-record.sh --release-id "$CD2_EDITION" --genre Electronic --plain-punctuation --out "$W/release.json"
plugin rip-cd/scripts/fetch-cover.sh "$CD2_EDITION" "$W/cover.jpg"
plugin audit-release/scripts/repair-release.sh plan --artist "Night Drive" --album "Afterglow Live" --album "Afterglow Live [Disc 2]" --release "$W/release.json" --cover "$W/cover.jpg" --out "$W/plan.json"
plugin audit-release/scripts/repair-release.sh apply "$W/plan.json"
snapshot
