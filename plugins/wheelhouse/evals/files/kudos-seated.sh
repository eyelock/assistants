#!/usr/bin/env bash
# kudos seated: Dredd and Tharg hold seats; no Kudos given yet.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse seated
release_graph >/dev/null
