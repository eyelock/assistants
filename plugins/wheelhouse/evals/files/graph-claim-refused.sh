#!/usr/bin/env bash
# work-graph claim-refused: the release graph, with the changelog already claimed by mccoist.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
read -r _ changelog _ _ < <(release_graph)
BEADS_ACTOR=mccoist bd update "$changelog" --claim --json >/dev/null
