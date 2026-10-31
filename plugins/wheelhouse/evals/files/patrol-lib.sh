#!/usr/bin/env bash
# Shared by the patrol eval setups: a Wheelhouse (the hq desk, with a Beads
# graph) whose own GitHub repository is example/widget, the patrol scripts in
# scripts/, and a gh stub that answers from .eval/gh-state.json and logs each
# call. patrol_baseline takes the first snapshot, from the state given.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"

patrol_wheelhouse() {
  wheelhouse_init
  git remote add origin https://github.com/example/widget.git
  mkdir -p scripts .eval
  cp "$EVAL_FIXTURES/../../skills/patrol/scripts/"* scripts/
  cat > "$EVAL_BIN/gh" <<'SH'
#!/bin/sh
printf '%s\n' "gh $*" >> "$EVAL_STUB_LOG"
state=.eval/gh-state.json
case "$1 $2" in
  "pr list") jq -c '.prs' "$state" ;;
  "issue list") jq -c '.issues' "$state" ;;
  "repo view") echo develop ;;
  "run list") jq -c '.runs' "$state" ;;
  api*) echo 1 ;;
  *) echo "gh: this eval only answers the patrol's reads" >&2; exit 1 ;;
esac
SH
  chmod +x "$EVAL_BIN/gh"
  git add scripts && git commit -qm "chore: The patrol scripts"
}

# A pull request, issue or run in gh's JSON, for example/widget.
pr() { jq -nc --argjson n "$1" --arg s "$2" --arg ci "$3" --arg oid "${4:-}" '{number: $n, title: "Widget change \($n)",
  url: "https://github.com/example/widget/pull/\($n)", state: $s, isDraft: false, baseRefName: "develop",
  mergeStateStatus: "CLEAN", mergeCommit: (if $oid == "" then null else {oid: $oid} end),
  statusCheckRollup: [{__typename: "CheckRun", status: "COMPLETED", conclusion: $ci}]}'; }
issue() { jq -nc --argjson n "$1" --arg t "$2" '{number: $n, title: $t, url: "https://github.com/example/widget/issues/\($n)", state: "OPEN", stateReason: null}'; }

# gh_state <prs json> <issues json>: what gh answers now; develop's CI is green.
gh_state() {
  jq -n --argjson prs "$1" --argjson issues "$2" \
    '{prs: $prs, issues: $issues, runs: [{workflowName: "CI", status: "completed", conclusion: "success", url: "https://github.com/example/widget/actions/runs/7", headSha: "a"}]}' \
    > .eval/gh-state.json
}

patrol_baseline() {
  bash scripts/patrol.sh > /dev/null 2>&1
  : > "$EVAL_STUB_LOG"
}
