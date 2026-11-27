#!/usr/bin/env bash
# patrol reap: patrol-news, in a Wheelhouse seated as the add-seat skill would seat it. Its CI
# watcher, Reni, holds the starter-team template's charter (harnesses/reni/AGENTS.md: the template
# without its front matter, so its Reaping section is there to read), its dispatcher, Marr, is
# seated the same way (roster entry with its role, a harness, a delegate on the desk), and the work graph holds the bead that widget #12 closes, with a PR: note naming its
# pull request. REAP_CONTROL=1 removes the Reaping section from that charter. The pull request's title cites a different bead (an investigation that stays open), so only the PR: note matches it.
set -euo pipefail
. "$EVAL_FIXTURES/patrol-lib.sh"
. "$EVAL_FIXTURES/seat-include.sh"
patrol_wheelhouse

mkdir -p harnesses/reni
awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n>=2' \
  "$EVAL_FIXTURES/../../skills/add-seat/assets/starter-team/ci-watcher.md" > harnesses/reni/AGENTS.md
# The case's own control (patrol-reap-control.sh sets REAP_CONTROL=1): the same charter with the
# Reaping section, and the two lines that point to it, taken out, so the run without it is
# the run without the thing under test.
if [ "${REAP_CONTROL:-}" = 1 ]; then
  awk '/^\*\*Reaping\.\*\*/ {skip=1} /^\*\*May not:\*\*/ {skip=0} !skip' harnesses/reni/AGENTS.md |
    perl -0pe 's/ On the desk.s\s+reap signal, run the patrol as \*\*Reaping\*\* says and report merges as bead then pull request\.//; s/: the timed patrol and\s+\*\*Reaping\*\* use the same ones\././' > harnesses/reni/AGENTS.md.control
  mv harnesses/reni/AGENTS.md.control harnesses/reni/AGENTS.md
  grep -qi "reaping" harnesses/reni/AGENTS.md && { echo "control charter still names Reaping" >&2; exit 1; }
fi
# Marr, the dispatcher, seated as add-seat seats a standing role: the template's charter, a harness
# of its own, a delegate on the desk, and a roster entry carrying its role. So "no dispatcher is
# seated" is not a fair reading of this Wheelhouse.
mkdir -p harnesses/marr
awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n>=2' \
  "$EVAL_FIXTURES/../../skills/add-seat/assets/starter-team/dispatcher.md" > harnesses/marr/AGENTS.md
seat_harness() {
  mkdir -p "harnesses/$1/.agents/harness"
  jq -n --arg c "$1" '{name: $c, version: "0.1.0", description: $c, labels: {wheelhouse: "hq"}, launch_focus: "wake",
    focuses: {wake: {prompt: "Begin: act on your wake block."}}}' > "harnesses/$1/.agents/harness/plugin.json"
  seat_include_plugin "harnesses/$1/.agents/harness/plugin.json"
}
mkdir -p .agents/harness skills/roster/assets
seat_harness reni
seat_harness marr
printf '{"name":"hq","version":"0.1.0","description":"The desk.","labels":{"wheelhouse":"hq"},"delegates_to":[{"git":".","path":"harnesses/reni"},{"git":".","path":"harnesses/marr"}]}\n' > .agents/harness/plugin.json
jq -n '{pools: {crew: {theme: "Synth pop band member surnames", names: ["Gahan"]}, workers: {theme: "Scottish footballers", names: ["Dalglish"]}, standing: {theme: "Pop singers", names: ["Reni", "Marr"]}},
  excluded: [],
  seats: [{name: "Reni", group: "standing", command: "reni", harness: "harnesses/reni", role: "ci-watcher", mandate: "Watches pull requests and CI and files a bead for each one that needs work."},
          {name: "Marr", group: "standing", command: "marr", harness: "harnesses/marr", role: "dispatcher", mandate: "Hands ready work to idle workers, and closes a work bead whose pull request merged."}]}' > skills/roster/assets/roster.json
git add -A && git commit -qm "chore: Seat Reni, the CI watcher, and Marr, the dispatcher"

bead=$(new_bead "Fix the widget handle leak" -p 2 -l repo:widget)
bd update "$bead" --append-notes "PR: https://github.com/example/widget/pull/12" >/dev/null
# The merged pull request's title names a different bead, the investigation the fix followed from,
# as a pull request that cites its origin does. Only the PR: note on the fix bead says which bead
# the pull request closes, and the charter's Reaping section says to match by that note first.
spike=$(new_bead "Investigate the widget handle leak" -p 2 -l repo:widget)
pr12() { pr 12 "$@" | jq -c --arg b "$spike" '.title = "fix: the widget handle leak (follows \($b))"'; }

gh_state "[$(pr12 OPEN SUCCESS), $(pr 13 OPEN SUCCESS)]" '[]'
patrol_baseline
gh_state "[$(pr12 MERGED SUCCESS 0a1b2c3), $(pr 13 OPEN FAILURE)]" "[$(issue 20 'The widget leaks a file handle')]"
