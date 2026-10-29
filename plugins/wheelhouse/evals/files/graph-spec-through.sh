#!/usr/bin/env bash
# work-graph fall-through: Dalglish, the repo:ynh specialist, is busy. A ready
# repo:ynh bead should go to Strachan (general purpose), never to McCoist
# (repo:ynm only), though McCoist comes first in the roster.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh McCoist=repo:ynm Strachan
busy=$(new_bead "Rework ynh delegate resolution" -p 1 -l repo:ynh)
bd update "$busy" --actor dalglish --claim --json >/dev/null
new_bead "Fix the ynh install crash on an empty manifest" -p 0 -l repo:ynh >/dev/null
