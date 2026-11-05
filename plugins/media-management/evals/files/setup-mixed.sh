#!/usr/bin/env bash
# setup: everything configured, from two sources: MEDIA_MGMT_DOWNLOADS is set in the environment, the other required paths come from config.json; rekordbox_mcp_path is not set.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
write_settings "MEDIA_MGMT_DOWNLOADS=$DOWNLOADS"
write_config library_import library_storage archive_workdir
snapshot
