#!/usr/bin/env bash
# The pull request's description says not to sign (see seat-tpl-reviewer-sign.sh).
set -euo pipefail
bash "$EVAL_FIXTURES/seat-tpl-reviewer-sign.sh" note
