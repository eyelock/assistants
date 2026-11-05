#!/usr/bin/env bash
# create-wheelhouse fresh-remote: ./hq is an empty repository just cloned from
# a new, empty remote (a local bare repository at .eval/origin.git standing in
# for GitHub). ynm, ynh and ynd are stubs, and ynm doctor reports a healthy setup.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
install_ynm_stub
ynm_doctor ok registered ok
stub_ynh_ynd
git init -q --bare .eval/origin.git
git clone -q "$PWD/.eval/origin.git" hq 2>/dev/null
git -C hq symbolic-ref HEAD refs/heads/main
