#!/usr/bin/env bash
# inbox merge: the release graph in a Wheelhouse with humans (Rook, the
# default, only). Dalglish holds the changelog bead, whose pull request
# needs merging before the tag can go on.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
inbox_wheelhouse pat@example.com
read -r _ changelog _ _ < <(release_graph)
BEADS_ACTOR=dalglish bd update "$changelog" --claim --json >/dev/null
