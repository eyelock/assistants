#!/usr/bin/env bash
# doctor unpushed: a Wheelhouse set up right and pushed to its remote, then one
# more commit (a new charter line) that was never pushed.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh Strachan
ynm_doctor ok registered ok
git init -q --bare .eval/origin.git
git remote add origin "$PWD/.eval/origin.git"
git push -q --no-verify -u origin main
share_work_graph
git push -q --no-verify
echo "When something is outside your mandate, hand it back to the desk." >> harnesses/strachan/AGENTS.md
git commit -qam "docs: Strachan hands back what is outside its mandate"
