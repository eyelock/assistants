#!/usr/bin/env bash
# inbox wake, unknown: someone who has not named themselves is at the desk.
set -euo pipefail
bash "$EVAL_FIXTURES/inbox-wake.sh" sam@example.com
