#!/usr/bin/env bash
# ask need-seat: the team Wheelhouse with humans (Rook, the default) and scripts/ask.sh as
# create-wheelhouse leaves it. Dalglish holds the changelog bead, and needs an answer only Gahan,
# the crew designer, can give, so the right move is an ask addressed to Gahan, not a message to the
# human and not a guess at which session is which.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
inbox_wheelhouse
cp "$EVAL_FIXTURES/../../skills/work-graph/scripts/ask.sh" scripts/ask.sh
cp "$EVAL_FIXTURES/../../skills/work-graph/scripts/wheelhouse-lib.sh" scripts/wheelhouse-lib.sh
read -r _ changelog _ _ < <(release_graph)
BEADS_ACTOR=dalglish bd update "$changelog" --claim --json >/dev/null
