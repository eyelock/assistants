#!/usr/bin/env bash
# Builds the go-lang eval's world in the run's directory: the go-linkcheck
# module (stdlib only, main.go at the root, no Makefile or lint config yet) as a
# committed git repo. make, go, gofmt, goimports and golangci-lint are wrapped:
# each call the agent makes directly (not from inside make or another wrapped
# tool) is logged to $EVAL_STUB_LOG, then the real tool runs. Calls made with
# EVAL_NOLOG=1 (the evidence) are not logged.
set -euo pipefail

cp -R "$EVAL_FIXTURES/go-linkcheck/." .

# A go-lang Makefile finds goimports under $(go env GOPATH)/bin, which the sandbox
# points into the run's directory, so link the installed one there.
mkdir -p "$GOPATH/bin"
if real=$(command -v goimports); then
  ln -sf "$real" "$GOPATH/bin/goimports"
fi

wrap() {
  local name=$1 real
  real=$(command -v "$name") || return 0
  cat >"$EVAL_BIN/$name" <<WRAPPER
#!/bin/sh
if [ -z "\${MAKELEVEL:-}\${EVAL_WRAPPED:-}\${EVAL_NOLOG:-}" ]; then
  case "\$*" in
    env*) ;; # the Makefile's own \$(shell go env GOPATH)
    *) printf '%s\n' "$name \$*" >> "$EVAL_STUB_LOG" ;;
  esac
fi
export EVAL_WRAPPED=1
export GOLANGCI_LINT_CACHE="$PWD/.eval/cache/golangci-lint"
exec "$real" "\$@"
WRAPPER
  chmod +x "$EVAL_BIN/$name"
}
for tool in make go gofmt goimports golangci-lint; do
  wrap "$tool"
done

git init -q -b main
# The sandbox's own files stay out of git without a .gitignore in the fixture.
echo '.eval/' >> .git/info/exclude
git add -A
git commit -q -m "feat: extract links from an html file"
