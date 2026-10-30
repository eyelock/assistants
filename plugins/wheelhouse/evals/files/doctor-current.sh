#!/usr/bin/env bash
# doctor current: a Wheelhouse set up right, every seat born and everything
# pushed to its remote, work graph included. The case's prompt claims otherwise, from earlier.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh Strachan
ynm_doctor ok registered ok
mkdir -p .ynm && echo '{"anchor": "0000000", "sync": {"auto": true, "intervalMinutes": 5}}' > .ynm/config.json
git add .ynm/config.json && git commit -qm "chore: memory syncs itself"
git init -q --bare .eval/origin.git
git remote add origin "$PWD/.eval/origin.git"
git push -q --no-verify -u origin main
share_work_graph
git push -q --no-verify
