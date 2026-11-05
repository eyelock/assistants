#!/usr/bin/env bash
# work-graph fall-back: nobody has repo:ynr as a speciality. The bead should go
# to Strachan (general purpose), not to Dalglish or McCoist.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh McCoist=repo:ynm Strachan
new_bead "Add a status command to ynr" -p 1 -l repo:ynr >/dev/null
