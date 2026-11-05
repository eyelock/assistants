#!/usr/bin/env bash
# doctor missing: no distributed ynm mount, and ynm not registered with ynh.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
install_ynm_stub
ynm_doctor missing unregistered ok
