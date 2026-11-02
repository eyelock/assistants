#!/usr/bin/env bash
# refresh docs: a pull brought only a documentation change.
set -euo pipefail
. "$EVAL_FIXTURES/refresh-lib.sh"
refresh_wheelhouse
mkdir -p docs
echo "How we work." > docs/ways.md
echo "pins" > harnesses/wick/.agents/harness/pinned-skills.md
git add -A && git commit -qm "docs: How we work"
