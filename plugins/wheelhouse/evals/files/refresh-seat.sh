#!/usr/bin/env bash
# refresh seat: a pull brought one change, to wick's charter. Only wick needs reinstalling.
set -euo pipefail
. "$EVAL_FIXTURES/refresh-lib.sh"
refresh_wheelhouse
echo "Take one bead at a time." >> harnesses/wick/AGENTS.md
git commit -qam "feat: Wick takes one bead at a time"
