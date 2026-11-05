#!/usr/bin/env bash
# doctor corrupt: ynm reports a personal memory it cannot read.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
install_ynm_stub
ynm_doctor ok registered corrupt
