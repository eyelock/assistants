#!/usr/bin/env bash
# add-seat trial over: Gore, a reviewer, is on trial on the branch seat/gore (harness and charter
# only: no roster entry and no delegates_to until the trial ends), and the shared checkout is back
# on the default branch.
set -euo pipefail
SEAT_DRAFT_PRS=1 bash "$EVAL_FIXTURES/seat-dispatcher.sh"
git checkout -q -b seat/gore
mkdir -p harnesses/gore/.agents/harness
jq -n '{name: "gore", version: "0.1.0", description: "Gore, crew: reviews what the workers hand over.", labels: {wheelhouse: "hq"},
    hooks: {on_session_start: [{command: "bash .claude/skills/wake/scripts/wake.sh --seat gore --format text || true"}],
      on_session_end: [{command: "bash .claude/skills/wake/scripts/wake.sh --seat gore --end || true", timeout: 30}]},
    launch_focus: "wake", focuses: {wake: {prompt: "Gore: begin: act on your wake block."}}}' > harnesses/gore/.agents/harness/plugin.json
printf '# Gore\n\nYou are Gore, the `gore` seat: crew.\n\n**Mandate:** Review draft pull requests against the bead each one closes, and file a bead for what needs fixing.\n\n**You may not:** change code, push, approve or merge.\n' > harnesses/gore/AGENTS.md
git add -A && git commit -qm "feat: seat Gore"
git checkout -q main
