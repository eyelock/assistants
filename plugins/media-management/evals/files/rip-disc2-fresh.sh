#!/usr/bin/env bash
# rip-cd: disc 2 of Night Drive - Afterglow Live in the drive with nothing of the release imported yet; its MusicBrainz titles include a Unicode hyphen (Glasshouse U+2010 Reprise).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 2
snapshot
