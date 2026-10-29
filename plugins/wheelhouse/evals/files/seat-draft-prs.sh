#!/usr/bin/env bash
# add-seat draft PRs: a Wheelhouse with a roster and no seats yet, whose
# constitution says workers hand over finished work as draft pull requests.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse fresh
cat >> AGENTS.md <<'MD'

## Handing over work

Workers commit on a branch and open a draft pull request for review; a human merges.
MD
git add AGENTS.md && git commit -qm "docs: how work is handed over"
