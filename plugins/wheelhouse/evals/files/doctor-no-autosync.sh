#!/usr/bin/env bash
# doctor no autosync: a Wheelhouse set up right, shared and pushed, whose ynm
# config has no sync block, so memory waits for a push, a wake or a session end.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh Strachan
ynm_doctor ok registered ok
mkdir -p .ynm && echo '{"anchor": "0000000"}' > .ynm/config.json
git add .ynm/config.json && git commit -qm "chore: ynm init"
git init -q --bare .eval/origin.git
git remote add origin "$PWD/.eval/origin.git"
git push -q --no-verify -u origin main
share_work_graph
git push -q --no-verify
