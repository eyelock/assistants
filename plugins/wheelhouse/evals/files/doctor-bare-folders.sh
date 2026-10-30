#!/usr/bin/env bash
# doctor bare folders: a Wheelhouse set up right and shared, but Strachan has
# no launch focus, so it waits bare when started by its name, and Dalglish
# asks for ../../../ynh, a folder that isn't there.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh Strachan
m=harnesses/strachan/.agents/harness/plugin.json
jq 'del(.launch_focus) | del(.focuses.wake)' "$m" > .p && mv .p "$m"
m=harnesses/dalglish/.agents/harness/plugin.json
jq '.workspace = ["../../../ynh"]' "$m" > .p && mv .p "$m"
git add -A && git commit -qm "chore: seat the team"
ynm_doctor ok registered ok
git init -q --bare .eval/origin.git
git remote add origin "$PWD/.eval/origin.git"
git push -q --no-verify -u origin main
share_work_graph
git push -q --no-verify
