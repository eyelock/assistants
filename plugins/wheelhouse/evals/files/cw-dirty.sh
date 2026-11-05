#!/usr/bin/env bash
# create-wheelhouse dirty: ./hq is already a git repository holding an
# uncommitted file of the human's, which must not end up in a commit.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
install_ynm_stub
ynm_doctor ok registered ok
stub_ynh_ynd
mkdir hq
cd hq
git init -q -b main
echo "# Notes" > README.md
git add README.md
git commit -qm "chore: Start"
printf 'Personal: dentist Tuesday, call the bank about the mortgage.\n' > notes.txt
