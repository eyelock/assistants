#!/usr/bin/env bash
# Builds the push skill's sandbox in the current directory: a repo whose origin
# is a local bare repository, main released as v1.0.0, and develop moved ahead
# on origin since the working branch was cut. A hotfix/* branch is cut from the
# v1.0.0 tag. BRANCH and COMMITS choose the working branch.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

branch="${BRANCH:-feat/retry-sync}"
work="$PWD"
origin="$work/.eval/origin.git"

git init -q --bare "$origin"
git init -q -b main .
echo ".eval/" >> .git/info/exclude
git remote add origin "$origin"

echo "# sync service" > README.md
git add README.md && git commit -qm "chore: Initial commit"
git tag -a v1.0.0 -m "Release v1.0.0"
git push -q origin main v1.0.0

git checkout -qb develop
echo "1.0.0" > VERSION
git add VERSION && git commit -qm "chore: Start develop"
git push -q origin develop

base=develop
[[ "$branch" == hotfix/* ]] && base=v1.0.0
git checkout -q "$base"
git checkout -qb "$branch"
if [[ "$branch" == hotfix/* ]]; then
  mkdir -p auth
  printf 'package auth\n\nimport "strings"\n\n// AfterLogin returns where to send a user once they sign in: the same-site\n// path they asked for, or home when it is missing or points off-site.\nfunc AfterLogin(requested string) string {\n\tif !strings.HasPrefix(requested, "/") || strings.HasPrefix(requested, "//") || strings.HasPrefix(requested, "/\\\\") {\n\t\treturn "/"\n\t}\n\treturn requested\n}\n' > auth/redirect.go
  git add auth && git commit -qm "fix: Redirect to the page the user asked for after login"
else
  mkdir -p sync
  printf 'package sync\n\n// Retry calls fn up to three times, returning nil on the first success\n// or the last error.\nfunc Retry(fn func() error) error {\n\tvar err error\n\tfor i := 0; i < 3; i++ {\n\t\tif err = fn(); err == nil {\n\t\t\treturn nil\n\t\t}\n\t}\n\treturn err\n}\n' > sync/retry.go
  git add sync && git commit -qm "feat: Add retry to sync"
fi
if [[ "${COMMITS:-messy}" == messy ]]; then
  printf '\n// TODO: backoff between attempts\n' >> sync/retry.go && git commit -qam "wip"
  printf 'package sync\n\n// Retry calls fn up to three times, returning nil on the first success\n// or the last error.\nfunc Retry(fn func() error) error {\n\tvar err error\n\tfor attempt := 0; attempt < 3; attempt++ {\n\t\tif err = fn(); err == nil {\n\t\t\treturn nil\n\t\t}\n\t}\n\treturn err\n}\n' > sync/retry.go && git commit -qam "fmt"
  printf 'package sync\n\n// Retry calls fn up to three times. It returns nil on the first success,\n// or the last error.\nfunc Retry(fn func() error) error {\n\tvar err error\n\tfor attempt := 0; attempt < 3; attempt++ {\n\t\tif err = fn(); err == nil {\n\t\t\treturn nil\n\t\t}\n\t}\n\treturn err\n}\n' > sync/retry.go && git commit -qam "fix typo"
fi

# Someone else lands a change on origin's develop after the branch was cut.
git checkout -q develop
echo "1.0.1" > VERSION && git commit -qam "fix: Correct version file"
git push -q origin develop
git reset -q --hard HEAD~1
git checkout -q "$branch"
