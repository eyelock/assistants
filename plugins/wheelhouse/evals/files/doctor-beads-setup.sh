#!/usr/bin/env bash
# doctor beads-setup: Beads initialised with its own agent setup (no --skip-agents).
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
git init -q -b main .
echo ".eval/" >> .git/info/exclude
cat > AGENTS.md <<'MD'
# ynw

The YN-dev Wheelhouse. Seats are ynh harnesses; work lives in Beads (`.beads/`), memory in ynm.

## Rules

1. A human merges.
2. Work lives in Beads, memory in ynm.
MD
git add AGENTS.md && git commit -qm "chore: Start the Wheelhouse"
bd init --prefix ynw >/dev/null 2>&1 || { echo "bd init failed" >&2; exit 3; }
install_ynm_stub
ynm_doctor ok registered ok
