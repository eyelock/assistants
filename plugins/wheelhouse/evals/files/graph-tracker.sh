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
    "pattern": "^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+$",
    "example": "https://github.com/eyelock/ynh/issues/680"
  },
  "release": { "name": "milestone" }
}
JSON
git add tracker.json && git commit -qm "chore: tracker config"
new_bead "Add --focus to ynh run" -t epic -p 1 >/dev/null
