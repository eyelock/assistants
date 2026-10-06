#!/usr/bin/env bash
# process-album: a fresh purchase of Summer Sampler, a four-artist compilation whose ZIPs are named after every artist; Apple Music and the NAS are empty.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
sampler_zips
snapshot
