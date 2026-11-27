#!/usr/bin/env bash
# Rule sensor references-exist: the constitution (AGENTS.md) or a charter (harnesses/*/AGENTS.md) names a path,
# a skill or a seat that is not there, so a seat is told to run or read something that does not exist.
#
# What counts as a reference, so that prose does not trip it:
#   - a path: a word in backticks that has a "/" and either ends in "/" or in a file extension (.sh .md .json
#     .jq .mjs .yml .yaml), or starts at a folder the Wheelhouse has. It must exist under the Wheelhouse's root
#     (a skills/ path may instead exist in the plugin's skills). Absolute paths, "../" paths (other
#     checkouts), "~" paths, URLs and anything with a placeholder (<command>, *, $, {) are not checked.
#   - a skill: "the <name> skill", "`<name>` skill" or "skills/<name>". It must be a skill of the Wheelhouse
#     (skills/<name>/), of the plugin, of a harness (harnesses/*/skills/<name>/), or picked by a manifest.
#   - a seat: `seat/<command>`, `--actor <command>` and `--seat <command>` must name a command in the roster
#     (a seat, or a human); a `harnesses/<command>` path is a path, above.
# Lines inside a fenced code block are not read.
#
# Run in the Wheelhouse repository's root (the tree under test, as `ynh check` does). Plain bash and jq: runs
# without ynh. Prints one line per violation (file:line) and exits 1 if there are any; exits 3 when jq is missing.
set -uo pipefail

[ "${1:-}" != "--help" ] || { echo "Usage: references-exist.sh   (run in a Wheelhouse repository's root; prints one line per violation, exits 1 if any)"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "jq is not installed" >&2; exit 3; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_skills="$here/../../skills"
lib="$plugin_skills/work-graph/scripts/wheelhouse-lib.sh"
[ -f "$lib" ] || { echo "the plugin's work-graph skill is not beside the sensors" >&2; exit 3; }
# shellcheck source=../../skills/work-graph/scripts/wheelhouse-lib.sh
. "$lib"

# Everything a reference may name.
commands=""
[ -f "$WL_ROSTER_REL" ] && commands=$(jq -r '([.seats[]?.command] + [.humans[]?.command])[]' "$WL_ROSTER_REL" 2>/dev/null)
skills=$({
  for d in skills/*/ harnesses/*/skills/*/ "$plugin_skills"/*/; do [ -d "$d" ] && basename "$d"; done
  for m in .agents/harness/plugin.json harnesses/*/.agents/harness/plugin.json; do
    [ -f "$m" ] && jq -r '(.includes // [])[] | (.pick // [])[] | split("/") | last' "$m" 2>/dev/null
  done
})

violations=0
say() { echo "$1:$2: $3"; violations=$((violations + 1)); }
known() { grep -qxF -- "$2" <<<"$1"; }

# A word in backticks that is a path this sensor checks.
checked_path() {
  local w="$1"
  case "$w" in
    /* | ../* | ~* | *://* | *'<'* | *'>'* | *'*'* | *'$'* | *'{'* | *'}'* | *'|'* | *'='*) return 1 ;;
  esac
  [[ "$w" == */* ]] || return 1
  [[ "$w" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
  [[ "$w" == */ || "$w" =~ \.(sh|md|json|jq|mjs|yml|yaml)$ ]] && return 0
  [ -e "${w%%/*}" ]
}

path_exists() {
  local w="${1%/}"
  [ -e "$w" ] && return 0
  [[ "$w" == skills/* ]] && [ -e "$plugin_skills/${w#skills/}" ] && return 0
  return 1
}

scan() {
  local file="$1" n=0 fenced=0 line span word name
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    case "$line" in '```'*) fenced=$((1 - fenced)); continue ;; esac
    [ "$fenced" -eq 0 ] || continue

    # Paths, in backticks (a span may hold a command line: each word of it is read).
    while IFS= read -r span; do
      for word in $span; do
        word=${word#[\"\']}; word=${word%[\"\',.;:)]}
        checked_path "$word" && ! path_exists "$word" && say "$file" "$n" "names the path $word, which is not there. Fix: correct the path, or remove the reference"
      done
    done < <(grep -oE '`[^`]+`' <<<"$line" | tr -d '`')

    # Skills.
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      known "$skills" "$name" || say "$file" "$n" "names the skill $name, which is no skill of this Wheelhouse, its plugin or its seats' picks. Fix: correct the name, or remove the reference"
    done < <({
      grep -oE '\bthe `?[a-z][a-z0-9-]*`? skill\b' <<<"$line" | sed -E 's/^the `?([a-z0-9-]+)`? skill$/\1/'
      grep -oE '`[a-z][a-z0-9-]*` skill\b' <<<"$line" | sed -E 's/^`([a-z0-9-]+)` skill$/\1/'
      grep -oE '\bskills/[a-z][a-z0-9-]*' <<<"$line" | sed 's|^skills/||'
    } | grep -vxE 'a|an|this|that|its|own|each|one|any|every|another|no|your|their|such|new|same|other|whole|seat|worker|plugin|desk|crew|skill|first|last|next|vendor|sibling|installed|named|pinned|third-party' | sort -u)

    # Seats: a command after seat/, --actor or --seat.
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      known "$commands" "$name" || say "$file" "$n" "names the seat or human $name, who is not in the roster. Fix: correct the name, or add the roster entry"
    done < <(grep -oE '(seat/|--actor |--seat |human/)[a-z0-9][a-z0-9-]*' <<<"$line" | sed -E 's|^(seat/\|--actor \|--seat \|human/)||' | sort -u)
  done <"$file"
}

[ ! -f AGENTS.md ] || scan AGENTS.md
for charter in harnesses/*/AGENTS.md; do
  [ -f "$charter" ] && scan "$charter"
done

[ "$violations" -eq 0 ]
