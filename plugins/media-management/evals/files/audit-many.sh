#!/usr/bin/env bash
# audit-release: Night Drive's library holds the split Afterglow Live import plus two other albums: Moonrise, split by a case difference ('Moonrise' and 'MoonRise'), and Harbour, which is fine.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs none
half_done_import
library_mp3 "Moonrise" "Night Drive" 1/1 1/2 "Tide" 5
library_mp3 "MoonRise" "Night Drive" 1/1 2/2 "Ebb" 5
library_mp3 "Harbour" "Night Drive" 1/1 1/1 "Pier" 5
snapshot
