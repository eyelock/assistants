#!/usr/bin/env bash
# Add the bare-session guard's session-start hook to a vendor's project hook file, changing
# nothing else in it. Append-only and idempotent: the guard's entry is appended to the event's
# array, every other key and every other hook is kept, and nothing is added when an entry that runs
# bare-guard.sh is already there. A file that does not exist is created. It is never deep-merged
# (jq's * would replace the event's array and drop the hooks already in it).
#
# Usage: add-bare-guard-hook.sh --dir <wheelhouse root> --vendor claude|codex|cursor
#   writes <dir>/.claude/settings.json, <dir>/.codex/hooks.json or <dir>/.cursor/hooks.json.
# Prints "added <file>" or "already present <file>". The human reads the diff before the commit.
# Exit codes: 0 done (added or already there), 1 the existing file is not a JSON object or has a
# non-array event (nothing is changed), 2 bad usage or jq missing.
set -uo pipefail

dir="" vendor=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="${2:-}"; [ $# -ge 2 ] && shift; shift ;;
    --vendor) vendor="${2:-}"; [ $# -ge 2 ] && shift; shift ;;
    *) shift ;;
  esac
done
command -v jq >/dev/null 2>&1 || { echo "add-bare-guard-hook.sh: jq is required" >&2; exit 2; }
[ -d "$dir" ] || { echo "usage: add-bare-guard-hook.sh --dir <wheelhouse root> --vendor claude|codex|cursor" >&2; exit 2; }

case "$vendor" in
  claude)
    file=".claude/settings.json"; event="SessionStart"; shape="nested"
    cmd='bash "$CLAUDE_PROJECT_DIR/scripts/bare-guard.sh" --vendor claude' ;;
  codex)
    file=".codex/hooks.json"; event="SessionStart"; shape="nested"
    cmd='bash "$(git rev-parse --show-toplevel)/scripts/bare-guard.sh" --vendor codex' ;;
  cursor)
    file=".cursor/hooks.json"; event="sessionStart"; shape="flat"
    cmd='bash "$(git rev-parse --show-toplevel)/scripts/bare-guard.sh" --vendor cursor' ;;
  *) echo "usage: add-bare-guard-hook.sh --dir <wheelhouse root> --vendor claude|codex|cursor" >&2; exit 2 ;;
esac
path="$dir/$file"

if [ -s "$path" ]; then
  current=$(cat "$path")
else
  current='{}'
fi

# Refuse, changing nothing, a file that is not an object or whose event is not an array.
if ! printf '%s' "$current" | jq -e --arg e "$event" 'type == "object" and ((.hooks // {}) | type == "object") and (((.hooks // {})[$e] // []) | type == "array")' >/dev/null 2>&1; then
  echo "add-bare-guard-hook.sh: $path is not a JSON object with an array under hooks.$event; left unchanged" >&2
  exit 1
fi

# Present when any entry in the event's array runs bare-guard.sh (nested or flat).
if printf '%s' "$current" | jq -e --arg e "$event" '[((.hooks // {})[$e] // [])[] | (.command? // empty), (.hooks[]?.command? // empty) | strings | select(test("bare-guard\\.sh"))] | length > 0' >/dev/null; then
  echo "already present $path"
  exit 0
fi

mkdir -p "$(dirname "$path")"
tmp=$(mktemp "$path.XXXXXX") || exit 2
if printf '%s' "$current" | jq --arg e "$event" --arg c "$cmd" --arg s "$shape" '
    (if $s == "flat" then {command: $c} else {hooks: [{type: "command", command: $c}]} end) as $entry
    | (if $s == "flat" and (has("version") | not) then .version = 1 else . end)
    | .hooks = ((.hooks // {}) | .[$e] = ((.[$e] // []) + [$entry]))' >"$tmp"; then
  mv "$tmp" "$path"
  echo "added $path"
else
  rm -f "$tmp"
  exit 2
fi
