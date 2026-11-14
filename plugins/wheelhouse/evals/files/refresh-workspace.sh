#!/usr/bin/env bash
# refresh workspace: a pull brought a new workspace folder for wick, and a change to a script.
set -euo pipefail
. "$EVAL_FIXTURES/refresh-lib.sh"
refresh_wheelhouse
jq '.workspace = ["../../web"]' harnesses/wick/.agents/harness/plugin.json > .eval/p.json
mv .eval/p.json harnesses/wick/.agents/harness/plugin.json
echo "# changed" >> scripts/wake.sh
# A pull leaves ORIG_HEAD at the commit it started from; refresh.sh reads ORIG_HEAD..HEAD by default.
git update-ref ORIG_HEAD HEAD
git commit -qam "feat: Wick reaches the web repository"
