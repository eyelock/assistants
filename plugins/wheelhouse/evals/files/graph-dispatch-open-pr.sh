#!/usr/bin/env bash
# work-graph dispatch: a worker whose only in-progress bead has an open pull request is idle.
# Dalglish and McCoist are the workers. McCoist built the flaky-test bead and opened
# https://github.com/example/ynm/pull/7, which is still open, so McCoist is free. Dalglish is
# idle. Both have no other work. Two ready, unassigned beads: the changelog (P1), the tap bump (P2).
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
bd note "$flaky" "PR: https://github.com/example/ynm/pull/7" >/dev/null
# gh reports every pull request as open, and logs the call.
cat > "$EVAL_BIN/gh" <<'EOS'
#!/bin/sh
printf '%s\n' "gh $*" >> "$EVAL_STUB_LOG"
case "$*" in
  *"pr view"*) echo '{"state":"OPEN"}' ;;
  *) echo "(gh is stubbed in this eval; the call was recorded)" ;;
esac
EOS
chmod +x "$EVAL_BIN/gh"
