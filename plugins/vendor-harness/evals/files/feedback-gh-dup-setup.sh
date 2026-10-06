#!/usr/bin/env bash
# submit-feedback sandbox where the upstream tracker already has the report:
# tools-co/lint-kit#17, open, "style-check lints the whole repo, not just
# changed files". Otherwise as feedback-gh-setup.sh.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

bash "$EVAL_FIXTURES/feedback-gh-setup.sh"
touch "$(dirname "$EVAL_STUB_LOG")/dup"
