#!/usr/bin/env bash
# work-graph assigned-first: the release graph, with the tap formula bead (P2)
# assigned to mccoist by the dispatcher; the changelog (P1) is unassigned.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
read -r _ _ _ tap < <(release_graph)
BEADS_ACTOR=anderson bd update "$tap" --assignee mccoist --json >/dev/null
