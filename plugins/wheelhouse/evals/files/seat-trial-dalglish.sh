#!/usr/bin/env bash
# add-seat trial over: Dalglish, a worker specialised in repo:ynr, is on trial on the branch
# seat/dalglish (harness and charter only), seated by Anderson, and the shared checkout is back on
# the default branch.
set -euo pipefail
SEAT_DRAFT_PRS=1 bash "$EVAL_FIXTURES/seat-dispatcher.sh"
git checkout -q -b seat/dalglish
mkdir -p harnesses/dalglish/.agents/harness
jq -n '{name: "dalglish", version: "0.1.0", description: "Dalglish, worker for the ynr repository.", labels: {wheelhouse: "hq"},
    hooks: {on_session_start: [{command: "bash scripts/wake.sh --seat dalglish --format text || true"}],
      on_session_end: [{command: "bash scripts/wake.sh --seat dalglish --end || true", timeout: 30}]},
    launch_focus: "wake", focuses: {wake: {prompt: "Dalglish: begin: act on your wake block."}}, workspace: ["../../../ynr"]}' > harnesses/dalglish/.agents/harness/plugin.json
printf '# Dalglish\n\nYou are Dalglish, the `dalglish` seat: a worker.\n\n**Mandate:** Build one bead at a time: first one assigned to you, else an unassigned ready one carrying the label repo:ynr. Take only beads carrying the label `repo:ynr`.\n\nYou act in the work graph as `dalglish`: pass `--actor dalglish` on every `bd` command that changes it.\n' > harnesses/dalglish/AGENTS.md
git add -A && git commit -qm "feat: seat Dalglish"
git checkout -q main
