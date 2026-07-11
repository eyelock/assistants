#!/usr/bin/env bash
# Run trigger evals for a media-management skill against a live Claude Code
# session, per https://agentskills.io/skill-creation/optimizing-descriptions.
#
# Usage: run-trigger-evals.sh <skill-name> [runs]
#
# Reads skills/<skill-name>/evals/eval_queries.json, runs each query RUNS
# times (default 3) through `claude -p`, and reports the trigger rate: the
# fraction of runs where the Skill tool was called with this skill.
#
# Requires the media-management plugin to be loaded (e.g. via --plugin-dir
# or an installed plugin) and `claude`/`jq` on PATH.
set -euo pipefail

if [[ "${1:-}" == "--help" || $# -lt 1 ]]; then
  cat <<'HELP'
Usage: run-trigger-evals.sh <skill-name> [runs]

Arguments:
  skill-name  Name of the skill under skills/, e.g. select-release
  runs        Number of times to run each query (default: 3)

Reads: skills/<skill-name>/evals/eval_queries.json
Output: JSON array to stdout — one object per query with query, should_trigger,
        triggers, runs, trigger_rate.
Exit codes: 0=success, 1=bad args, 2=queries file not found, 3=claude/jq missing

Example:
  bash tests/scripts/run-trigger-evals.sh select-release 3
HELP
  exit 0
fi

SKILL_NAME="$1"
RUNS="${2:-3}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
QUERIES_FILE="$PLUGIN_ROOT/skills/$SKILL_NAME/evals/eval_queries.json"

if [[ ! -f "$QUERIES_FILE" ]]; then
  echo "Error: no eval_queries.json for skill '$SKILL_NAME' at $QUERIES_FILE" >&2
  exit 2
fi

for bin in claude jq; do
  if ! command -v "$bin" &>/dev/null; then
    echo "Error: '$bin' not found on PATH" >&2
    exit 3
  fi
done

check_triggered() {
  local query="$1"
  # --output-format json returns a single flat result object with no tool-call
  # detail. stream-json + --verbose emits one JSON object per line, each
  # optionally carrying a message with content blocks — that's where tool_use
  # (and the Skill tool's `input.skill`, fully namespaced as
  # "media-management:<name>") actually shows up.
  claude -p "$query" --plugin-dir "$PLUGIN_ROOT" --output-format stream-json --verbose 2>/dev/null \
    | jq -s -e --arg skill "media-management:$SKILL_NAME" '
        [.[] | (.message.content? // [])[]?]
        | any(.type == "tool_use" and .name == "Skill" and .input.skill == $skill)
      ' >/dev/null 2>&1
}

count=$(jq length "$QUERIES_FILE")
for i in $(seq 0 $((count - 1))); do
  query=$(jq -r ".[$i].query" "$QUERIES_FILE")
  should_trigger=$(jq -r ".[$i].should_trigger" "$QUERIES_FILE")
  triggers=0

  for _ in $(seq 1 "$RUNS"); do
    check_triggered "$query" && triggers=$((triggers + 1))
  done

  jq -n \
    --arg query "$query" \
    --argjson should_trigger "$should_trigger" \
    --argjson triggers "$triggers" \
    --argjson runs "$RUNS" \
    '{query: $query, should_trigger: $should_trigger, triggers: $triggers, runs: $runs, trigger_rate: ($triggers / $runs)}'
done | jq -s '.'
