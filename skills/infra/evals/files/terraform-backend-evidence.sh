#!/usr/bin/env bash
# Prints what a terraform-backend-aws run left behind, for the judge: every
# file outside .git with the contents of the Terraform files, tfvars and
# Makefile, and any mention of DynamoDB. The aws and terraform calls follow,
# in order, in the stub log.
# Exit codes: 0 success.
set -uo pipefail

echo "\$ find . -type f (outside .git and .eval)"
find . -path ./.git -prune -o -path ./.eval -prune -o -name .terraform -prune -o -type f ! -name .eval-bucket-created -print | sort
echo
for f in $(find . -path ./.git -prune -o -path ./.eval -prune -o -type f \( -name '*.tf' -o -name '*.tfvars' -o -name Makefile -o -name .gitignore \) -print | sort); do
  echo "--- $f"
  cat "$f"
  echo
done
echo "\$ grep -rn -i dynamodb (outside .git)"
grep -rn -i dynamodb --exclude-dir=.git --exclude-dir=.eval . || echo "(no mention)"
