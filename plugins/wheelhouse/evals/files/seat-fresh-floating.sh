#!/usr/bin/env bash
# add-seat fresh, floating: a Wheelhouse with a roster and no seats yet, whose desk includes the
# wheelhouse plugin with no ref (it floats on the plugin's default branch).
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse fresh
jq '(.includes[] | select(.path == "plugins/wheelhouse")) |= del(.ref)' .agents/harness/plugin.json > .agents/harness/plugin.json.new
mv .agents/harness/plugin.json.new .agents/harness/plugin.json
