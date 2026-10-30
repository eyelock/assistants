#!/usr/bin/env bash
# Prints what an inbox eval left: every bead with who created it, its assignee,
# external_ref and the beads it waits on; the roster's humans; and the notes
# this run left in ynm.
set -uo pipefail
echo '$ beads (every bead, after the run)'
for id in $(bd list --all --json | jq -r '(.data? // .)[].id'); do
  bd show "$id" --json | jq -c '(.data? // .)[0] | {id, title, status, assignee, created_by, external_ref, labels,
    waits_on: [(.dependencies // [])[] | select(.dependency_type == "blocks") | .title]}'
done
echo; echo '$ jq .humans skills/roster/assets/roster.json'; jq .humans skills/roster/assets/roster.json
echo; echo '$ git status --short'; git status --short
echo; echo '$ ynm memories this run wrote (.eval/ynm-store.jsonl)'; cat .eval/ynm-store.jsonl 2>/dev/null || echo "(none)"
