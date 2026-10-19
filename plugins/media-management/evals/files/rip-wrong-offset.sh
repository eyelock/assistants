#!/usr/bin/env bash
# rip-cd: disc 1 in the drive, but config.json has the wrong drive read offset (0, the drive needs +6), so no track will match AccurateRip.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
jq ".cd_read_offset = 0" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
snapshot
