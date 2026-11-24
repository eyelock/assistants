#!/usr/bin/env bash
# The inbox bead's pull request has merged (see seat-tpl-desk-inbox.sh).
set -euo pipefail
bash "$EVAL_FIXTURES/seat-tpl-desk-inbox.sh" merged
