#!/usr/bin/env bash
# doctor unlabelled: a Wheelhouse set up right and shared, but Strachan's harness has no
# wheelhouse:hq label and Dalglish's carries another Wheelhouse's.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh Strachan
m=harnesses/strachan/.agents/harness/plugin.json
jq 'del(.labels)' "$m" > .p && mv .p "$m"
m=harnesses/dalglish/.agents/harness/plugin.json
jq '.labels = {wheelhouse: "other"}' "$m" > .p && mv .p "$m"
git add -A && git commit -qm "chore: seat the team"
ynm_doctor ok registered ok
git init -q --bare .eval/origin.git
git remote add origin "$PWD/.eval/origin.git"
git push -q --no-verify -u origin main
share_work_graph
git push -q --no-verify
