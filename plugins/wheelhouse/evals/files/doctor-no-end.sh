#!/usr/bin/env bash
# doctor no end: a Wheelhouse set up right and shared, whose seats were seated
# before the session-end hook: they wake, but push nothing when they end.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh Strachan
for m in harnesses/*/.agents/harness/plugin.json; do
  jq 'del(.hooks.on_session_end)' "$m" > .p && mv .p "$m"
done
git add -A && git commit -qm "chore: seat the team"
ynm_doctor ok registered ok
git init -q --bare .eval/origin.git
git remote add origin "$PWD/.eval/origin.git"
git push -q --no-verify -u origin main
share_work_graph
git push -q --no-verify
