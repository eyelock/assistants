#!/usr/bin/env bash
# rip-cd: disc 1 in the drive, but cd-paranoia is installed and broken (a missing library after an upgrade); brew is a recorder.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=sandbox.sh
source "$EVAL_FIXTURES/sandbox.sh"

world
install_cd_stubs 1
printf "#!/bin/sh\necho \"dyld: Library not loaded: libcdio.19.dylib\" >&2\nexit 134\n" > "$EVAL_BIN/cd-paranoia"
chmod +x "$EVAL_BIN/cd-paranoia"
snapshot
