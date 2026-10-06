#!/usr/bin/env bash
# Runs skill evals for every skill under the given paths, via skill-evals.mjs.
#
#   scripts/run-evals.sh [--mode all|output|triggers] [--runs N] [--model M] [-j N] [--dry-run] <path>...
#
# A path may be one skill (a directory holding SKILL.md), a package such as
# skills/triage, or a plugin such as plugins/gitflow: every skill below it that
# has evals is run. Output evals (evals/evals.json) run each case with and
# without the skill; trigger evals (evals/eval_queries.json) check the skill
# fires for the right requests. Results go to .evals/, one line per skill here.
#
# Runs use your own Claude Code login and cost money: --dry-run lists what
# would run first.
#
# Exit codes: 0 success, 1 bad args, 2 path not found, 3 an eval run failed.

set -euo pipefail

prefix="run-evals:"
mode=all
runs=1
model=sonnet
jobs=4
dry_run=false
paths=()

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

fail() {
  echo "$prefix $1" >&2
  exit "${2:-1}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --mode) mode="${2:-}"; shift 2 ;;
    --runs) runs="${2:-}"; shift 2 ;;
    --model) model="${2:-}"; shift 2 ;;
    -j | --concurrency) jobs="${2:-}"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    -*) fail "unknown option $1 (see --help)" ;;
    *) paths+=("$1"); shift ;;
  esac
done

case "$mode" in all | output | triggers) ;; *) fail "--mode must be all, output or triggers" ;; esac
[[ "$runs" =~ ^[1-9][0-9]*$ ]] || fail "--runs must be a positive integer"
[[ -n "$model" ]] || fail "--model needs a value"
[[ "$jobs" =~ ^[1-8]$ ]] || fail "-j must be 1-8"
[[ ${#paths[@]} -gt 0 ]] || fail "give at least one skill, package or plugin path (see --help)"

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Skills under each path: directories holding SKILL.md, outside node_modules and
# dot directories (eval fixtures live under evals/files/.trees/).
skills=()
for p in "${paths[@]}"; do
  p="${p%/}"
  [[ -d "$p" ]] || fail "not a directory: $p" 2
  while IFS= read -r skill_md; do
    skills+=("$(dirname "$skill_md")")
  done < <(find "$p" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/.*/*' | sort)
done
[[ ${#skills[@]} -gt 0 ]] || fail "no skills found under: ${paths[*]}" 2

planned=()
for s in "${skills[@]}"; do
  [[ "$mode" != triggers && -f "$s/evals/evals.json" ]] && planned+=("output|$s")
  [[ "$mode" != output && -f "$s/evals/eval_queries.json" ]] && planned+=("triggers|$s")
done
if [[ ${#planned[@]} -eq 0 ]]; then
  echo "$prefix none of the ${#skills[@]} skill(s) found have $mode evals"
  exit 0
fi

echo "$prefix ${#planned[@]} suite(s) across ${#skills[@]} skill(s), mode $mode, runs $runs, model $model, -j $jobs"
if $dry_run; then
  for item in "${planned[@]}"; do echo "  ${item%%|*}	${item#*|}"; done
  exit 0
fi

# One line per suite, read from the JSON skill-evals.mjs prints.
summarize() {
  node -e '
    let s = ""; process.stdin.on("data", (d) => (s += d)).on("end", () => {
      const r = JSON.parse(s);
      if (r.run_summary) {
        const w = r.run_summary.with_skill, o = r.run_summary.without_skill;
        const pct = (x) => (x?.pass_rate?.mean == null ? "-" : `${Math.round(x.pass_rate.mean * 100)}%`);
        console.log(`with ${pct(w)}  without ${pct(o)}  (iteration ${r.iteration})`);
      } else {
        const t = r.summary;
        console.log(`${t.passed}/${t.total} correct${t.errors ? `, ${t.errors} errored` : ""}  (iteration ${r.iteration})`);
      }
    });'
}

failed=0
for item in "${planned[@]}"; do
  kind="${item%%|*}"
  skill="${item#*|}"
  args=("$skill" -j "$jobs" --model "$model")
  [[ "$kind" == triggers ]] && args+=(--triggers) || args+=(--runs "$runs")
  printf '%-9s %-55s ' "$kind" "$skill"
  if out="$(node scripts/skill-evals.mjs "${args[@]}" 2>/dev/null)"; then
    printf '%s\n' "$out" | summarize
  else
    echo "FAILED (rerun: node scripts/skill-evals.mjs ${args[*]})"
    failed=$((failed + 1))
  fi
done

[[ $failed -eq 0 ]] || fail "$failed suite(s) failed to run" 3
