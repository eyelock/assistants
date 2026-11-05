#!/usr/bin/env bash
# add-seat dredd: Dredd already holds the PR/CI watcher seat.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse dredd
