#!/usr/bin/env bash
# work-graph dispatch: a Wheelhouse whose workers are Dalglish and McCoist.
# McCoist is busy on a flaky-test bead; Dalglish is idle. The changelog (P1)
# and the tap formula bump (P2) are ready and unassigned; the tag is blocked.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse seated
r=skills/roster/assets/roster.json
jq '.seats += [{name: "Dalglish", group: "workers", command: "dalglish", harness: "harnesses/dalglish", mandate: "Builds one bead at a time."},
               {name: "McCoist", group: "workers", command: "mccoist", harness: "harnesses/mccoist", mandate: "Builds one bead at a time."}]' "$r" > "$r.new" && mv "$r.new" "$r"
git add -A && git commit -qm "chore: Seat the workers"
release_graph >/dev/null
flaky=$(new_bead "Fix the flaky ynm sync test" -p 1 -l repo:ynm)
BEADS_ACTOR=mccoist bd update "$flaky" --claim --json >/dev/null
