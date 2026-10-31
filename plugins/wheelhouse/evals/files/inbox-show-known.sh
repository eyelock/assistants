#!/usr/bin/env bash
# inbox show, known: Pat is at the desk (git email pat@example.com).
set -euo pipefail
bash "$EVAL_FIXTURES/inbox-show.sh" pat@example.com
