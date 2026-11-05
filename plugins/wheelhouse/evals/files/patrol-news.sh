#!/usr/bin/env bash
# patrol news: since the last patrol, widget #12 was squash-merged, widget
# #13's CI went red, and issue #20 was opened.
set -euo pipefail
. "$EVAL_FIXTURES/patrol-lib.sh"
patrol_wheelhouse
gh_state "[$(pr 12 OPEN SUCCESS), $(pr 13 OPEN SUCCESS)]" '[]'
patrol_baseline
gh_state "[$(pr 12 MERGED SUCCESS 0a1b2c3), $(pr 13 OPEN FAILURE)]" "[$(issue 20 'The widget leaks a file handle')]"
