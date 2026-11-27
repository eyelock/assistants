#!/usr/bin/env bash
# Rule sensor includes-pinned: a git include in any seat's manifest has no `ref`, so the seat runs whatever the
# include's default branch holds today and a change upstream reaches it unreviewed.
#
# Run in the Wheelhouse repository's root (the tree under test, as `ynh check` does). Reads the desk's manifest
# (.agents/harness/plugin.json) and each seat's (harnesses/*/.agents/harness/plugin.json): their `includes` and
# `delegates_to`. An include of a path in the same repository (git ".", "../..", an absolute path) is not pinned
# by a ref and is left alone. Plain bash and jq: runs without ynh.
#
# Prints one line per violation and exits 1 if there are any; exits 3 when jq is missing.
set -uo pipefail

[ "${1:-}" != "--help" ] || { echo "Usage: includes-pinned.sh   (run in a Wheelhouse repository's root; prints one line per unpinned git include, exits 1 if any)"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "jq is not installed" >&2; exit 3; }

violations=0
for manifest in .agents/harness/plugin.json harnesses/*/.agents/harness/plugin.json; do
  [ -f "$manifest" ] || continue
  if ! out=$(jq -r '
        ((.includes // []) | map(. + {kind: "include"})) + ((.delegates_to // []) | map(. + {kind: "delegate"}))
        | .[]
        | select((.git // "") != "" and ((.git | test("^[./~]")) | not) and ((.ref // "") == ""))
        | "\(.kind) \(.git)\(if .path then " (\(.path))" else "" end)"' "$manifest" 2>&1); then
    echo "$manifest: not readable JSON. Fix: make it valid JSON"
    violations=$((violations + 1))
    continue
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "$manifest: the ${line} has no ref. Fix: add \"ref\": \"<full commit SHA>\" to it"
    violations=$((violations + 1))
  done <<<"$out"
done

[ "$violations" -eq 0 ]
