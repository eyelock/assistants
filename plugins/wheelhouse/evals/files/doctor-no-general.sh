#!/usr/bin/env bash
# doctor no-general: a Wheelhouse set up right, except that its workers are all
# specialists (Dalglish repo:ynh, McCoist repo:ynm), with no general-purpose one.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh McCoist=repo:ynm
ynm_doctor ok registered ok
