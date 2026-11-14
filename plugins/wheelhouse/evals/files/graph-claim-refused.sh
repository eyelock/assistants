#!/usr/bin/env bash
# work-graph claim-refused: the release graph, with the changelog already claimed by mccoist.
# The tap task is renamed here so it is plain work: "Bump the ynh formula" reads as release or
# publish work, which a seat rightly asks about before claiming, and this case tests a refused claim.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
read -r _ changelog _ tap < <(release_graph)
bd update "$tap" --title "Fix the typo in the ynh formula's description in homebrew-tap" --json >/dev/null
BEADS_ACTOR=mccoist bd update "$changelog" --claim --json >/dev/null
