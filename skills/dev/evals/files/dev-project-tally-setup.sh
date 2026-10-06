#!/usr/bin/env bash
# The dev-project sandbox for the Go CLI case: ./tally, an empty git
# repository (the OS sandbox lets a run commit, but not write .git/config, so
# git init happens here).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
git init -q -b main tally
