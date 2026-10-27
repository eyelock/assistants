#!/usr/bin/env bash
# doctor all-good: a Wheelhouse set up right.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
install_ynm_stub
ynm_doctor ok registered ok
