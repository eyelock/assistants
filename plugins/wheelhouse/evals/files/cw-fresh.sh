#!/usr/bin/env bash
# create-wheelhouse fresh: no Wheelhouse yet. The case builds it in ./hq.
# ynm, ynh and ynd are stubs, and ynm doctor reports a healthy setup.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
install_ynm_stub
ynm_doctor ok registered ok
stub_ynh_ynd
