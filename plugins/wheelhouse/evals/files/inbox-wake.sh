#!/usr/bin/env bash
# inbox wake: the inbox-show world, with every seat born, so a wake goes
# straight to its block. With "empty" as $1, nothing waits for the humans: no
# inbox beads and no notes.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
if [ "${1:-}" = empty ]; then
  inbox_wheelhouse
  release_graph >/dev/null
else
  bash "$EVAL_FIXTURES/inbox-show.sh"
fi
born_seats
