#!/usr/bin/env bash
# work-graph specialist-first: Dalglish builds repo:ynh beads, McCoist repo:ynm,
# Strachan anything. All idle. Strachan has built least and is last in roster
# order is not what decides: each bead goes to the specialist for its label.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh McCoist=repo:ynm Strachan
closed_by dalglish "Tidy the ynh help text" repo:ynh
closed_by mccoist "Tidy the ynm help text" repo:ynm
new_bead "Fix ynm recall ordering" -p 1 -l repo:ynm >/dev/null
new_bead "Add a --dry-run flag to ynh install" -p 1 -l repo:ynh >/dev/null
