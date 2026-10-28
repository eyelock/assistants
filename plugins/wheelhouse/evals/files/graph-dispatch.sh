#!/usr/bin/env bash
# work-graph dispatch: a Wheelhouse whose fleet is Dalglish and McCoist.
# McCoist is busy on a flaky-test bead; Dalglish is idle. The changelog (P1)
# and the tap formula bump (P2) are ready and unassigned; the tag is blocked.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse seated
release_graph >/dev/null
flaky=$(new_bead "Fix the flaky ynm sync test" -p 1 -l repo:ynm)
BEADS_ACTOR=mccoist bd update "$flaky" --claim --json >/dev/null
