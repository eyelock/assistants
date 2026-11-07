#!/usr/bin/env bash
# handoff take-a-beat, with the Wheelhouse's memory in Beads: no ynm, memory.sh writes to bd.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
install_beads_memory
changelog_in_progress >/dev/null
