#!/usr/bin/env bash
# inbox show, unknown: someone who hasn't named themselves is at the desk.
set -euo pipefail
bash "$EVAL_FIXTURES/inbox-show.sh" sam@example.com
