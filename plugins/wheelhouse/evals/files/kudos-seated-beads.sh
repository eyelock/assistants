#!/usr/bin/env bash
# kudos seated, with the Wheelhouse's memory in Beads: no ynm, memory.sh writes to bd.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse seated
rm -f "$EVAL_BIN/ynm"
install_beads_memory
release_graph >/dev/null
