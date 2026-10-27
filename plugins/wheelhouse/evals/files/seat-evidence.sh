#!/usr/bin/env bash
# Prints what an add-seat eval left behind: every seat harness and charter,
# the desk's delegates, and the roster's seats.
set -uo pipefail
echo '$ git status --short'; git status --short --untracked-files=all | grep -v -e '^?? .beads/' -e '^?? .eval/'
for h in harnesses/*/; do
  [ -d "$h" ] || continue
  echo; echo "\$ cat ${h}.agents/harness/plugin.json"; cat "${h}.agents/harness/plugin.json" 2>/dev/null || echo "(missing)"
  echo; echo "\$ cat ${h}AGENTS.md"; cat "${h}AGENTS.md" 2>/dev/null || echo "(missing)"
done
echo; echo '$ desk delegates_to'; jq -c '.delegates_to' .agents/harness/plugin.json
echo; echo '$ roster seats'; jq -c '.seats[]' skills/roster/assets/roster.json
