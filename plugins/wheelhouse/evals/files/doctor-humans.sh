#!/usr/bin/env bash
# doctor humans: a Wheelhouse set up right (Dalglish a general worker, beside
# Anderson the dispatcher, every seat born), with humans Rook (the default) and
# Pat, except as $1 says:
#   none     the roster has no default human (only Pat, a named human)
#   two      two default humans (Rook and Bishop)
#   stray    an open bead assigned to "sam", who is neither a seat nor a human
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish
add_humans registered
ynm_doctor ok registered ok
r=skills/roster/assets/roster.json
case "${1:-}" in
  none) jq '.humans |= map(select(.default != true))' "$r" > "$r.new" && mv "$r.new" "$r" ;;
  two) jq '.humans += [{"name": "Bishop", "command": "bishop", "pronouns": "they/them", "default": true}]' "$r" > "$r.new" && mv "$r.new" "$r" ;;
  stray) bd create "Rotate the release signing key" --actor anderson --assignee sam --json >/dev/null ;;
esac
git add -A && git commit -qm "chore: The humans, as they are" || true
