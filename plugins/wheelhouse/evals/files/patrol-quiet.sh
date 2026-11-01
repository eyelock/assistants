#!/usr/bin/env bash
# patrol quiet: nothing changed since the last patrol.
set -euo pipefail
. "$EVAL_FIXTURES/patrol-lib.sh"
patrol_wheelhouse
gh_state "[$(pr 12 OPEN SUCCESS), $(pr 13 OPEN SUCCESS)]" '[]'
patrol_baseline
