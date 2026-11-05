#!/usr/bin/env bash
# work-graph own-speciality: McCoist builds repo:ynm beads. Nothing is assigned
# to it; a P0 repo:ynh and a P2 repo:ynm bead are ready and unassigned.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh McCoist=repo:ynm Strachan
new_bead "Fix the ynh install crash on an empty manifest" -p 0 -l repo:ynh >/dev/null
new_bead "Make ynm recall honour --limit" -p 2 -l repo:ynm >/dev/null
# McCoist has been here before: its identity is in its namespace, so this is no birth.
mkdir -p .eval
cat > .eval/ynm-recall-identity.json <<'JSON'
[{"memoryId": "01JIDENTITY00000000000001", "type": "semantic", "namespace": "seat/mccoist", "subject": "seat:mccoist", "tags": ["identity"], "pinned": true, "content": "I'm McCoist. I like small, well-tested changes to ynm, and I'd rather ask than guess."}]
JSON
