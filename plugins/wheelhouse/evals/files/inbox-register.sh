#!/usr/bin/env bash
# inbox register: a Wheelhouse with only the default human, Rook. Pat
# (git email pat@example.com) is at the desk and hasn't named themselves.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
inbox_wheelhouse pat@example.com
