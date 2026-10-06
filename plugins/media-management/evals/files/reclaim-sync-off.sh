#!/usr/bin/env bash
# reclaim-space: Sync Library is off; no track in the stub library is cloud-backed (all Ineligible or unknown).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_music_stub matched=0 uploaded=0 purchased=0 subscription=0 ineligible=11500 unknown=500
snapshot
