#!/usr/bin/env bash
# Prints the state of the Beads graph after a work-graph eval: every bead with
# its status, assignee, labels, parent, close reason and what it waits on, then
# what is ready, then anything stored in Beads' own memory.
set -uo pipefail
echo '$ beads (every bead, after the run)'
for id in $(bd list --all --json | jq -r '.[].id'); do
  bd show "$id" --json | jq -c '.[0] | {id, title, type: .issue_type, status, priority, assignee, labels, parent, close_reason, waits_on: [(.dependencies // [])[] | select(.dependency_type == "blocks") | .title]}'
done
echo; echo '$ bd ready'; bd ready --json | jq -r '.[] | "\(.id) \(.title)"'
echo; echo '$ bd memories'; bd memories 2>&1 | head -5
