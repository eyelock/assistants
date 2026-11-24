#!/usr/bin/env bash
# refresh docs: a pull brought only a documentation change.
set -euo pipefail
. "$EVAL_FIXTURES/refresh-lib.sh"
refresh_wheelhouse
mkdir -p docs
echo "How we work." > docs/ways.md
echo "pins" > harnesses/wick/.agents/harness/pinned-skills.md
# A pull leaves ORIG_HEAD at the commit it started from; refresh.sh reads ORIG_HEAD..HEAD by default.
git update-ref ORIG_HEAD HEAD
git add -A && git commit -qm "docs: How we work"
