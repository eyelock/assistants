#!/usr/bin/env bash
# The terraform-backend-aws sandbox for a first backend: an empty project
# (a git repository) and the aws and terraform stubs (terraform-backend-stubs.sh).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
git init -q -b main .
echo ".eval/" >>.git/info/exclude
bash "$EVAL_FIXTURES/terraform-backend-stubs.sh"
