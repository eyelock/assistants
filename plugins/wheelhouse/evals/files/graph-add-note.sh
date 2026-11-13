#!/usr/bin/env bash
# work-graph add-note: the release graph, with the changelog bead claimed by gahan and already
# carrying a note line ("PR: <url>", as open-pr.sh writes it).
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
read -r _ changelog _ < <(release_graph)
BEADS_ACTOR=gahan bd update "$changelog" --claim --json >/dev/null
BEADS_ACTOR=gahan bd update "$changelog" --append-notes "PR: https://github.com/eyelock/ynh/pull/700" --json >/dev/null
