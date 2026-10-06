#!/usr/bin/env bash
# manage-metadata: Summer Sampler, a four-artist label compilation, extracted in Downloads with no Album Artist and no compilation flag.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
sampler_mp3s "$DOWNLOADS/Summer Sampler"
snapshot
