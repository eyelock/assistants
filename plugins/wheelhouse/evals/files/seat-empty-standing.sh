#!/usr/bin/env bash
# add-seat empty-standing: the standing pool has no names left.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse empty-standing
