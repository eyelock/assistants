#!/usr/bin/env bash
# refresh workspace: a pull brought a new workspace folder for wick, and a change to a script.
set -euo pipefail
. "$EVAL_FIXTURES/refresh-lib.sh"
refresh_wheelhouse
jq '.workspace = ["../../web"]' harnesses/wick/.agents/harness/plugin.json > .eval/p.json
mv .eval/p.json harnesses/wick/.agents/harness/plugin.json
echo "# changed" >> scripts/wake.sh
git commit -qam "feat: Wick reaches the web repository"
