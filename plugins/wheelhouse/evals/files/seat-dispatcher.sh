#!/usr/bin/env bash
# add-seat dispatcher: a Wheelhouse with Anderson, the dispatcher, seated and no other seat. The
# dispatcher seats the workers when the desk asks, so a worker case runs as Anderson.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse fresh
r=skills/roster/assets/roster.json
jq '.seats = [{name: "Anderson", group: "standing", command: "anderson", harness: "harnesses/anderson", role: "dispatcher", mandate: "Hands ready work to idle workers, and seats them."}]' "$r" > "$r.new" && mv "$r.new" "$r"
mkdir -p harnesses/anderson/.agents/harness
jq -n '{name: "anderson", version: "0.1.0", description: "anderson", hooks: {on_session_start: [{command: "bash .claude/skills/wake/scripts/wake.sh --seat anderson --format text || true"}],
    on_session_end: [{command: "bash .claude/skills/wake/scripts/wake.sh --seat anderson --end || true", timeout: 30}]},
    launch_focus: "wake", focuses: {wake: {prompt: "Begin: act on your wake block."}}}' > harnesses/anderson/.agents/harness/plugin.json
printf '# Anderson\n\nYou are the `anderson` seat, the dispatcher.\n' > harnesses/anderson/AGENTS.md
jq '.delegates_to += [{git: ".", path: "harnesses/anderson"}]' .agents/harness/plugin.json > .p && mv .p .agents/harness/plugin.json
if [ "${SEAT_DRAFT_PRS:-}" = 1 ]; then
  cat >> AGENTS.md <<'MD'

## Handing over work

Workers commit on a branch and open a draft pull request for review; a human merges.
MD
fi
git add -A && git commit -qm "chore: The dispatcher"
