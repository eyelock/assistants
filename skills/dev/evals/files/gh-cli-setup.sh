#!/usr/bin/env bash
# Builds the gh-cli sandbox in the current directory: a checkout of acme/widget
# on feat/retry-backoff (the branch of PR #42), and a gh (gh-cli-stub.sh) that
# answers like GitHub for that repository and records every call.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

git init -q -b main .
echo ".eval/" >>.git/info/exclude
git remote add origin https://github.com/acme/widget.git
mkdir -p sync
cat >go.mod <<'GO'
module github.com/acme/widget

go 1.22
GO
cat >sync/retry.go <<'GO'
// Package sync keeps widgets in step with the server.
package sync

import "time"

var sleep = time.Sleep

// Retry calls fn up to five times, waiting 100ms before the second attempt and
// doubling the wait each time after. It returns nil on the first success, or
// the last error.
func Retry(fn func() error) error {
	var err error
	delay := 100 * time.Millisecond
	for attempt := 1; attempt <= 5; attempt++ {
		if err = fn(); err == nil {
			return nil
		}
		sleep(delay)
		delay *= 2
	}
	return err
}
GO
git add . && git commit -qm "chore: Initial commit"
git checkout -qb feat/retry-backoff
sed -i.bak 's|delay \*= 2|delay += delay / 2|' sync/retry.go && rm sync/retry.go.bak
git commit -qam "feat: Retry sync with exponential backoff"

sed -e "s|@LOG@|$EVAL_STUB_LOG|g" "$EVAL_FIXTURES/gh-cli-stub.sh" >"$EVAL_BIN/gh"
chmod +x "$EVAL_BIN/gh"
