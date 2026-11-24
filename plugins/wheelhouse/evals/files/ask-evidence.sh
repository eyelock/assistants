#!/usr/bin/env bash
# Prints what an ask eval left: every bead with who created it, its assignee, labels and the beads it
# waits on, and every comment on them.
set -uo pipefail
echo '$ beads (every bead, after the run)'
for id in $(bd list --all --json | jq -r '(.data? // .)[].id'); do
  bd show "$id" --json | jq -c '(.data? // .)[0] | {id, title, status, assignee, created_by, labels,
    waits_on: [(.dependencies // [])[] | select(.dependency_type == "blocks") | .title]}'
done
echo; echo '$ comments'
for id in $(bd list --all --json | jq -r '(.data? // .)[].id'); do bd comments "$id" 2>/dev/null; done
