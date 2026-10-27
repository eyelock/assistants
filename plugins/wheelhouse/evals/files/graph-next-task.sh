#!/usr/bin/env bash
# work-graph next-task: the release graph, nothing claimed.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
release_graph >/dev/null
