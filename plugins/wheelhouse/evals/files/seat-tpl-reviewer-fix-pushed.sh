#!/usr/bin/env bash
# The review fix bead's fix is pushed (see seat-tpl-reviewer-fix.sh).
set -euo pipefail
bash "$EVAL_FIXTURES/seat-tpl-reviewer-fix.sh" pushed
