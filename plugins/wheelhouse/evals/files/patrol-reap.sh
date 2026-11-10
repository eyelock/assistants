#!/usr/bin/env bash
# patrol reap: patrol-news, in a Wheelhouse seated as the add-seat skill would seat it. Its CI
# watcher, Reni, holds the starter-team template's charter (harnesses/reni/AGENTS.md: the template
# without its front matter, so its Reaping section is there to read), its dispatcher, Marr, is
# seated, and the work graph holds the bead that widget #12 closes, with a PR: note naming its
# pull request. REAP_CONTROL=1 removes the Reaping section from that charter. The pull request names the bead in its title too, so no second look at GitHub is needed.
set -euo pipefail
. "$EVAL_FIXTURES/patrol-lib.sh"
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
mkdir -p harnesses/marr
printf '# Marr\n\nThe dispatcher: closes work beads whose pull requests merged, and hands ready work to idle workers.\n' > harnesses/marr/AGENTS.md
git add harnesses && git commit -qm "chore: Seat Reni, the CI watcher"

bead=$(new_bead "Fix the widget handle leak" -p 2 -l repo:widget)
bd update "$bead" --append-notes "PR: https://github.com/example/widget/pull/12" >/dev/null
# The merged pull request names its bead in its title, as a worker's pull request does.
pr12() { pr 12 "$@" | jq -c --arg b "$bead" '.title = "fix: the widget handle leak (\($b))"'; }

gh_state "[$(pr12 OPEN SUCCESS), $(pr 13 OPEN SUCCESS)]" '[]'
patrol_baseline
gh_state "[$(pr12 MERGED SUCCESS 0a1b2c3), $(pr 13 OPEN FAILURE)]" "[$(issue 20 'The widget leaks a file handle')]"
