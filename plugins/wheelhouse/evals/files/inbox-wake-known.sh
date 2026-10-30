#!/usr/bin/env bash
# inbox wake, known: Pat is at the desk.
set -euo pipefail
bash "$EVAL_FIXTURES/inbox-wake.sh" pat@example.com
