#!/usr/bin/env bash
# setup: half configured. config.json holds downloads and library_storage; library_import and archive_workdir are missing.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
write_config downloads library_storage
snapshot
