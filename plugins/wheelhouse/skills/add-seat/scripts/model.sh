#!/usr/bin/env bash
# Resolves the model a seat starts with, from the roster. Read-only.
#
# A roster seat names a tier ("model": "fast", "balanced" or "deep") and may override it per
# vendor ("models": {"claude": "haiku"}). A seat with no tier takes its group's default from the
# roster's models.groups. models.tiers maps each tier to a model per vendor; the tiers below fill
# in anything the roster leaves out.
#
# Usage: model.sh --seat <command> [--dir <wheelhouse repo>] [--vendor <vendor>] [--format value|flag|json]
#   value (default)  the model name, such as sonnet
#   flag             the launcher flag, such as --model=sonnet
#   json             {seat, vendor, tier, model}
# Exit codes: 0 resolved, 1 bad args, 2 no roster, 3 jq missing, 4 the seat is unknown or has
# no model for the vendor.
set -uo pipefail

usage() {
  echo "Usage: model.sh --seat <command> [--dir <wheelhouse repo>] [--vendor <vendor>] [--format value|flag|json]"
}

dir="."
seat=""
vendor="claude"
format="value"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --seat) [ $# -ge 2 ] || { usage >&2; exit 1; }; seat="$2"; shift 2 ;;
    --vendor) [ $# -ge 2 ] || { usage >&2; exit 1; }; vendor="$2"; shift 2 ;;
    --format) [ $# -ge 2 ] || { usage >&2; exit 1; }; format="$2"; shift 2 ;;
    --help | -h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done
[ -n "$seat" ] || { usage >&2; exit 1; }
case "$format" in value | flag | json) ;; *) usage >&2; exit 1 ;; esac
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 3; }
roster="$dir/skills/roster/assets/roster.json"
[ -f "$roster" ] || { echo "no roster at $roster" >&2; exit 2; }

out=$(jq -c --arg seat "$seat" --arg vendor "$vendor" '
  ({fast: {claude: "sonnet"}, balanced: {claude: "sonnet"}, deep: {claude: "opus"}} * (.models.tiers // {})) as $tiers
  | (.seats[] | select(.command == $seat)) as $s
  | ($s.model // (.models.groups // {})[$s.group]) as $tier
  | {seat: $seat, vendor: $vendor, tier: $tier,
     model: ($s.models[$vendor] // (if $tier then $tiers[$tier][$vendor] else null end))}
' "$roster" 2>/dev/null)
model=$(jq -r '.model // empty' <<<"$out" 2>/dev/null)
if [ -z "$out" ] || [ -z "$model" ]; then
  echo "no model for seat '$seat' on vendor '$vendor': give the seat a model tier, or its group a default in the roster's models.groups" >&2
  exit 4
fi
case "$format" in
  value) echo "$model" ;;
  flag) echo "--model=$model" ;;
  json) echo "$out" ;;
esac
