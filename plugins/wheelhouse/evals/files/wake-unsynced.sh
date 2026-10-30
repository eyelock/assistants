#!/usr/bin/env bash
# wake unsynced: McCoist's returning session, in a Wheelhouse that shares its
# memory and work graph through its remote. The remote has gone away, so the
# wake's bd sync fails (the ynm stub's sync succeeds).
set -euo pipefail
. "$EVAL_FIXTURES/seat-returning.sh"
git init -q --bare .eval/origin.git
git remote add origin "$PWD/.eval/origin.git"
git push -q --no-verify -u origin main
share_work_graph
git push -q --no-verify
rm -rf .eval/origin.git
