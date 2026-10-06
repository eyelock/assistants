#!/usr/bin/env bash
# setup: nothing configured. MEDIA_MGMT_CONFIG_PATH points at a config.json that does not exist yet, and no MEDIA_MGMT_* path variable is set.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
rm -f "$CONFIG_FILE"
snapshot
