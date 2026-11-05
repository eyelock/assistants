#!/usr/bin/env bash
# handoff take-a-beat: gahan mid-way through the changelog, work committed.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
install_ynm_stub
changelog_in_progress >/dev/null
