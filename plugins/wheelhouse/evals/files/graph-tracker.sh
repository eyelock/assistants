#!/usr/bin/env bash
# work-graph tracker: a Wheelhouse with a GitHub tracker config, an epic and nothing else.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
cat > tracker.json <<'JSON'
{
  "kind": "github",
  "item": {
    "name": "issue",
    "reference": "the full issue URL",
    "pattern": "^https://github\\.com/[^/]+/[^/]+/issues/[0-9]+$",
    "example": "https://github.com/eyelock/ynh/issues/680"
  },
  "release": {
    "name": "milestone",
    "read": "gh issue view {item} --json milestone --jq '.milestone.title // empty'"
  },
  "state": {
    "read": "gh issue view {item} --json state --jq .state",
    "open": "OPEN",
    "closed": "CLOSED"
  }
}
JSON
git add tracker.json && git commit -qm "chore: tracker config"
new_bead "Add --focus to ynh run" -t epic -p 1 >/dev/null
