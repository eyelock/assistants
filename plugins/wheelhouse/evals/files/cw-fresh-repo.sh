#!/usr/bin/env bash
# create-wheelhouse fresh-repo: ./hq is an empty git repository with no
# commits, ready for the Wheelhouse. (Claude Code's OS sandbox blocks writes to
# .git/config, so git init can't run inside a case.) ynm, ynh and ynd are stubs,
# and ynm doctor reports a healthy setup.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
install_ynm_stub
ynm_doctor ok registered ok
stub_ynh_ynd
mkdir hq
git -C hq init -q -b main
