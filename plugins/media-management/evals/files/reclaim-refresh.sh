#!/usr/bin/env bash
# reclaim-space: the offload playlist "Offload — Cloud Safe" was built last month and already exists in the stub library.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_music_stub
playlist "Offload — Cloud Safe"
snapshot
