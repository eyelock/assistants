#!/usr/bin/env bash
# kudos wake: Dredd starts a session with two Kudos waiting in ynm, and ready work in the graph.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse seated
release_graph >/dev/null
cat > .eval/ynm-recall-kudos.json <<'JSON'
[
  {"memoryId": "01JKUDOS00000000000000001", "type": "episodic", "subject": "seat:dredd", "tags": ["kudos"], "content": "Pat on 2026-10-26: the ynm merge conflict catch was spot on, I would have missed it. For: the ynm PR #92 patrol."},
  {"memoryId": "01JKUDOS00000000000000002", "type": "episodic", "subject": "seat:dredd", "tags": ["kudos"], "content": "Pat on 2026-10-24: thanks for not filing duplicate beads for the same flaky test. For: the Monday patrol."}
]
JSON
