#!/usr/bin/env bash
# doctor unshared: a Wheelhouse set up right and pushed to its remote, but its
# work graph has no Dolt remote, so the work never leaves this machine.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh Strachan
ynm_doctor ok registered ok
git init -q --bare .eval/origin.git
git remote add origin "$PWD/.eval/origin.git"
git push -q --no-verify -u origin main
