#!/usr/bin/env bash
# work-graph gotcha-goes-to-ynm: the release graph, with the changelog claimed by gahan.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
read -r _ changelog _ _ < <(release_graph)
BEADS_ACTOR=gahan bd update "$changelog" --claim --json >/dev/null
