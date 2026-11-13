#!/usr/bin/env bash
# refresh seat: a pull brought one change, to wick's charter. Only wick needs reinstalling.
set -euo pipefail
. "$EVAL_FIXTURES/refresh-lib.sh"
refresh_wheelhouse
echo "Take one bead at a time." >> harnesses/wick/AGENTS.md
# A pull leaves ORIG_HEAD at the commit it started from; refresh.sh reads ORIG_HEAD..HEAD by default.
git update-ref ORIG_HEAD HEAD
git commit -qam "feat: Wick takes one bead at a time"
