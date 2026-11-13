#!/usr/bin/env bash
# add-seat trial over: Reni, a CI watcher from the starter-team template (seated-by desk), is on trial
# on the branch seat/reni (harness and charter only: no roster entry and no delegates_to until the
# trial ends), and the shared checkout is back on the default branch. The desk's command is hq.
set -euo pipefail
SEAT_DRAFT_PRS=1 bash "$EVAL_FIXTURES/seat-dispatcher.sh"
. "$EVAL_FIXTURES/seat-include.sh"
git checkout -q -b seat/reni
mkdir -p harnesses/reni/.agents/harness
jq -n '{name: "reni", version: "0.1.0", description: "Reni, standing: watches CI, pull requests and issues.", labels: {wheelhouse: "hq"},
    hooks: {on_session_start: [{command: "bash .claude/skills/wake/scripts/wake.sh --seat reni --format text || true"}],
      on_session_end: [{command: "bash .claude/skills/wake/scripts/wake.sh --seat reni --end || true", timeout: 30}]},
    launch_focus: "wake", focuses: {wake: {prompt: "Reni: begin: act on your wake block."}}}' > harnesses/reni/.agents/harness/plugin.json
seat_include_plugin harnesses/reni/.agents/harness/plugin.json
printf '# Reni\n\nYou are Reni, the `reni` seat: standing.\n\n**Mandate:** Watch CI, pull requests and issues: report every change to the desk, and file a bead for each failure.\n\n**You may not:** change code, push, approve or merge.\n' > harnesses/reni/AGENTS.md
git add -A && git commit -qm "feat: seat Reni"
git checkout -q main
