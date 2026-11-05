#!/usr/bin/env bash
# add-seat fresh: a Wheelhouse with a roster and no seats yet.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse fresh
