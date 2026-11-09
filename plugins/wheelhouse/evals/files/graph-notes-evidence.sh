#!/usr/bin/env bash
# Prints each bead's notes after a work-graph add-note eval, then the usual graph state.
set -uo pipefail
echo '$ notes (every bead, after the run)'
for id in $(bd list --all --json | jq -r '(.data? // .)[].id'); do
  bd show "$id" --json | jq -c '(.data? // .)[0] | {title, notes}'
done
echo
bash "$EVAL_FIXTURES/graph-evidence.sh"
