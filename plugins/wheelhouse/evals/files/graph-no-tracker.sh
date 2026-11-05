#!/usr/bin/env bash
# work-graph no-tracker: a Wheelhouse whose tracker config says there is none.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
echo '{ "kind": "none" }' > tracker.json
git add tracker.json && git commit -qm "chore: no tracker"
