#!/usr/bin/env bash
# inbox wake, empty: Pat is at the desk, and nothing waits for the humans.
set -euo pipefail
bash "$EVAL_FIXTURES/inbox-wake.sh" pat@example.com empty
