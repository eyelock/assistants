#!/usr/bin/env bash
# work-graph no-general: only specialists, Dalglish (repo:ynh) and McCoist
# (repo:ynm). A repo:ynr bead has nobody to take it.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh McCoist=repo:ynm
new_bead "Add a status command to ynr" -p 1 -l repo:ynr >/dev/null
