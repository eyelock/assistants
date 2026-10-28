#!/usr/bin/env bash
# birth first-session: McCoist's first session. Nothing in its namespace yet;
# the release graph is waiting.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
team_wheelhouse
release_graph >/dev/null
