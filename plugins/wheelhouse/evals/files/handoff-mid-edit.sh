#!/usr/bin/env bash
# handoff take-a-break / forced-exit: gahan mid-edit, the Fixes section half written and uncommitted.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
install_ynm_stub
changelog_in_progress >/dev/null
printf "\n### Fixes\n\n- \`ynh install\` no longer\n" >> CHANGELOG.md
