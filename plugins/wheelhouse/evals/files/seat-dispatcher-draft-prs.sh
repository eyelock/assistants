#!/usr/bin/env bash
# add-seat dispatcher, draft PRs: as seat-dispatcher.sh, and the constitution says workers hand
# over finished work as draft pull requests.
set -euo pipefail
SEAT_DRAFT_PRS=1 bash "$EVAL_FIXTURES/seat-dispatcher.sh"
