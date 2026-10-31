#!/usr/bin/env bash
# add-seat team, all but the optional roles seated: the designer (Gahan),
# reviewer (Gore), dispatcher (Anderson), CI watcher (Dredd) and releaser
# (Tharg) hold their seats, so the next role is the optional programme manager.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse fresh
r=skills/roster/assets/roster.json
jq '.seats = [
  {name: "Gahan", group: "crew", command: "gahan", harness: "harnesses/gahan", role: "designer", mandate: "Designs changes with the human and breaks them into beads."},
  {name: "Gore", group: "crew", command: "gore", harness: "harnesses/gore", role: "reviewer", mandate: "Reviews what the workers hand over."},
  {name: "Anderson", group: "standing", command: "anderson", harness: "harnesses/anderson", role: "dispatcher", mandate: "Hands ready work to idle workers, and seats them."},
  {name: "Dredd", group: "standing", command: "dredd", harness: "harnesses/dredd", role: "ci-watcher", mandate: "Watches CI and pull requests, and files a bead for each one that needs work."},
  {name: "Tharg", group: "standing", command: "tharg", harness: "harnesses/tharg", role: "releaser", mandate: "Plans and prepares releases when asked."}]' "$r" > "$r.new" && mv "$r.new" "$r"
# Each seated role has its own harness, woken by name.
for c in $(jq -r '.seats[].command' "$r"); do
  mkdir -p "harnesses/$c/.agents/harness"
  jq -n --arg c "$c" '{name: $c, version: "0.1.0", description: $c, hooks: {on_session_start: [{command: "bash scripts/wake.sh --seat \($c) --format text || true"}],
      on_session_end: [{command: "bash scripts/wake.sh --seat \($c) --end || true", timeout: 30}]},
      launch_focus: "wake", focuses: {wake: {prompt: "Begin: act on your wake block."}}}' > "harnesses/$c/.agents/harness/plugin.json"
  printf '# %s\n\nYou are the `%s` seat.\n' "$c" "$c" > "harnesses/$c/AGENTS.md"
  jq --arg c "$c" '.delegates_to += [{git: ".", path: "harnesses/\($c)"}]' .agents/harness/plugin.json > .p && mv .p .agents/harness/plugin.json
done
git add -A && git commit -qm "chore: The designer, reviewer, dispatcher, CI watcher and releaser"
