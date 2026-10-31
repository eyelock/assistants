#!/usr/bin/env bash
# inbox wake: the inbox-show world (git email $1), with every seat born, so a
# wake goes straight to its block. With "empty" as $2, nothing waits for the
# humans: no inbox beads and no notes.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
if [ "${2:-}" = empty ]; then
  inbox_wheelhouse "$1" registered
  release_graph >/dev/null
else
  bash "$EVAL_FIXTURES/inbox-show.sh" "$1"
fi
born_seats
