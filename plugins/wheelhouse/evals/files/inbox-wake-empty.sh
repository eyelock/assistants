#!/usr/bin/env bash
# inbox wake, empty: nothing waits for the humans.
set -euo pipefail
bash "$EVAL_FIXTURES/inbox-wake.sh" empty
