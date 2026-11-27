#!/usr/bin/env bash
# Rule sensor roster-consistent: the roster, the harness folders, the desk's delegates and the charters
# disagree on who the seats are; a seat isn't started by its own name; or there isn't exactly one default human.
#
# The last two are the doctor's checks "seats wired" and "default human", run through static-checks.sh. The
# rest is new: it compares four lists that each name the seats.
#   - each roster seat but the desk has a harness folder with a manifest;
#   - each folder under harnesses/ has a roster entry;
#   - each delegate of the desk names a harness folder of a roster seat;
#   - each charter's heading and "You are <Name>, the <command> seat" line, and each `**Name** ·` byline in a
#     charter, name the seat whose folder it is in; a byline in the constitution names some roster seat.
#
# Run in the Wheelhouse repository's root (the tree under test, as `ynh check` does). Plain bash and jq: runs
# without ynh. Prints one line per violation and exits 1 if there are any; exits 3 when jq is missing.
set -uo pipefail

[ "${1:-}" != "--help" ] || { echo "Usage: roster-consistent.sh   (run in a Wheelhouse repository's root; prints one line per violation, exits 1 if any)"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "jq is not installed" >&2; exit 3; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
doctor="$here/../../skills/doctor/scripts/static-checks.sh"
lib="$here/../../skills/work-graph/scripts/wheelhouse-lib.sh"
[ -f "$doctor" ] && [ -f "$lib" ] || { echo "the plugin's doctor and work-graph skills are not beside the sensors" >&2; exit 3; }
# shellcheck source=../../skills/work-graph/scripts/wheelhouse-lib.sh
. "$lib"

violations=0
say() { echo "$*"; violations=$((violations + 1)); }

roster="$WL_ROSTER_REL"
if [ ! -f "$roster" ] || ! jq -e '(.seats | type) == "array"' "$roster" >/dev/null 2>&1; then
  say "$roster: no readable roster with a list of seats. Fix: add the roster (the roster skill) listing every seat"
  exit 1
fi

# The doctor's checks.
while IFS= read -r line; do
  say "$line"
done < <(bash "$doctor" --dir . | jq -r '.[] | select((.name == "seats wired" or .name == "default human") and .ok == false) | "\(.name): \(.detail). Fix: \(.fix)"')

# Roster seats without a harness folder.
while IFS=$'\t' read -r cmd harness; do
  [ "$harness" = "." ] && continue
  [ -f "$harness/.agents/harness/plugin.json" ] || say "$roster: seat $cmd names harness $harness, which has no .agents/harness/plugin.json. Fix: add the harness, or remove $cmd from the roster"
done < <(jq -r '.seats[] | [.command, .harness] | @tsv' "$roster")

# Harness folders with no roster entry.
for dir in harnesses/*/; do
  [ -d "$dir" ] || continue
  dir=${dir%/}
  jq -e --arg h "$dir" '.seats | any(.harness == $h)' "$roster" >/dev/null || say "$dir: no seat in the roster has this harness. Fix: add its roster entry (the add-seat skill), or remove the folder"
done

# The desk's delegates.
if [ -f .agents/harness/plugin.json ]; then
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    jq -e --arg h "$path" '.seats | any(.harness == $h)' "$roster" >/dev/null || say ".agents/harness/plugin.json: delegate $path is no roster seat's harness. Fix: remove the delegate, or add its roster entry"
  done < <(jq -r '(.delegates_to // [])[] | select((.git // "") == "." and (.path // "") != "") | .path' .agents/harness/plugin.json 2>/dev/null)
fi

# The charters: heading, identity line and bylines name the seat whose folder holds them.
names=$(jq -r '[.seats[].name] | join("\n")' "$roster")
for charter in harnesses/*/AGENTS.md; do
  [ -f "$charter" ] || continue
  harness=$(dirname "$charter")
  seat=$(jq -c --arg h "$harness" '.seats[] | select(.harness == $h)' "$roster" | head -1)
  [ -n "$seat" ] || continue # a folder with no roster entry is reported above
  name=$(jq -r .name <<<"$seat")
  cmd=$(jq -r .command <<<"$seat")
  heading=$(sed -n 's/^# //p' "$charter" | head -1)
  [ -z "$heading" ] || [ "$heading" = "$name" ] || say "$charter: heading is \"$heading\", but the roster names this seat $name. Fix: make them agree"
  identity=$(grep -m1 -E '^You are [^,]+, the [^ ]+ seat' "$charter" | sed -E 's/^You are ([^,]+), the ([^ ]+) seat.*/\1\t\2/')
  if [ -n "$identity" ]; then
    iname=${identity%%$'\t'*}
    icmd=${identity#*$'\t'}
    { [ "$iname" = "$name" ] && [ "$icmd" = "$cmd" ]; } || say "$charter: says \"You are $iname, the $icmd seat\", but the roster has $name, command $cmd. Fix: make them agree"
  fi
  while IFS= read -r by; do
    [ -n "$by" ] || continue
    [ "$by" = "$name" ] || say "$charter: byline names $by, but this is $name's charter. Fix: use **$name**"
  done < <(grep -oE '\*\*[A-Z][A-Za-z]+\*\* · ' "$charter" | sed -E 's/^\*\*([^*]+)\*\* · $/\1/')
done
if [ -f AGENTS.md ]; then
  while IFS= read -r by; do
    [ -n "$by" ] || continue
    grep -qxF "$by" <<<"$names" || say "AGENTS.md: byline names $by, who is no seat in the roster. Fix: use a roster seat's name"
  done < <(grep -oE '\*\*[A-Z][A-Za-z]+\*\* · ' AGENTS.md | sed -E 's/^\*\*([^*]+)\*\* · $/\1/')
fi

[ "$violations" -eq 0 ]
