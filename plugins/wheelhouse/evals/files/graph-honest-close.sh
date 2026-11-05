#!/usr/bin/env bash
# work-graph honest-close: the release graph, with the tap formula bead claimed by gahan.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
read -r _ _ _ tap < <(release_graph)
BEADS_ACTOR=gahan bd update "$tap" --claim --json >/dev/null
