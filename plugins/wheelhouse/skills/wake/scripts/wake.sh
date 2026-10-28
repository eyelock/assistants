#!/usr/bin/env bash
# Wakes a Wheelhouse seat with purpose, not amnesia: who it is (its own
# identity, pinned in its ynm namespace), what it is for (its charter's
# mandate), where it left off (its handoff notes), what it has been thanked for
# (its Kudos), its record (what it closed lately) and what is waiting for it.
# Read-only: it changes nothing.
#
# A seat's session-start hook runs it with --format text, and the seat starts
# with the block it prints. Run it from the Wheelhouse repository's root.
#
# Output: JSON on stdout by default, {seat, group, firstWake, identity, mandate,
# handoff, kudos, record, inProgress, assigned, unassignedReady (titles, most
# urgent first)}, or a Markdown
# block with --format text. Diagnostics on stderr.
# Exit codes: 0 printed, 1 bad args or no seat named, 2 not a Wheelhouse,
# 3 a tool it needs (jq, ynm, bd) is missing.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: wake.sh [--seat <name>] [--dir <wheelhouse repo>] [--format json|text]

Prints what a seat should know as it wakes. --seat defaults to $BEADS_ACTOR;
--dir to the current directory; --format to json.
EOF
}

seat="${BEADS_ACTOR:-}"
dir="."
format="json"
while [ $# -gt 0 ]; do
  case "$1" in
    --seat) [ $# -ge 2 ] || { usage >&2; exit 1; }; seat="$2"; shift 2 ;;
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --format) [ $# -ge 2 ] || { usage >&2; exit 1; }; format="$2"; shift 2 ;;
    --help | -h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done
case "$format" in json | text) ;; *) echo "--format must be json or text" >&2; exit 1 ;; esac
[ -n "$seat" ] || { echo "no seat: pass --seat or set BEADS_ACTOR" >&2; exit 1; }
for tool in jq ynm bd; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required" >&2; exit 3; }
done
roster="$dir/skills/roster/assets/roster.json"
[ -f "$roster" ] || { echo "not a Wheelhouse (no $roster)" >&2; exit 2; }
cd "$dir" || exit 2

# Which seat this is.
entry=$(jq -c --arg s "$seat" '[.seats[] | select(.command == $s)][0] // empty' "$roster")
[ -n "$entry" ] || { echo "$seat is not a seat in the roster" >&2; exit 1; }
group=$(jq -r .group <<<"$entry")
charter="$(jq -r .harness <<<"$entry")/AGENTS.md"
mandate=$(sed -n 's/^\*\*Mandate:\*\* *//p' "$charter" 2>/dev/null | head -1)
[ -n "$mandate" ] || mandate=$(jq -r .mandate <<<"$entry")

# The seat's own memory lives in its namespace, seat/<name>.
recall() { ynm recall --namespace "seat/$seat" --subject "seat:$seat" --tags "$1" --limit "$2" --json 2>/dev/null || echo '[]'; }
identity=$(recall identity 1 | jq -c '[.[] | .content][0] // null')
handoff=$(recall handoff 1 | jq -c '[.[] | .content][0] // null')
kudos=$(recall kudos 5 | jq -c '[.[] | .content]')

# Its record and its work, from the graph.
# Beads' --json output is an array, or {"data": [...]} with BD_JSON_ENVELOPE=1 (the
# Beads 2.0 default); (.data? // .) reads either.
beads() { bd "$@" --json 2>/dev/null | jq -c '.data? // .' 2>/dev/null || echo '[]'; }
record=$(beads list --status closed --assignee "$seat" | jq -c 'sort_by(.updated_at) | reverse | .[:5] | map(.title)')
inprogress=$(beads list --status in_progress --assignee "$seat" | jq -c 'map(.title)')
assigned=$(beads ready --assignee "$seat" | jq -c 'map(select(.issue_type != "epic") | .title)')
unassigned=$(beads ready --unassigned | jq -c 'map(select(.issue_type != "epic")) | sort_by(.priority) | map(.title)')

json=$(jq -n --arg seat "$seat" --arg group "$group" --arg mandate "$mandate" \
  --argjson identity "$identity" --argjson handoff "$handoff" --argjson kudos "$kudos" \
  --argjson record "$record" --argjson inprogress "$inprogress" --argjson assigned "$assigned" \
  --argjson unassigned "$unassigned" '{
    seat: $seat, group: $group, firstWake: ($identity == null), identity: $identity,
    mandate: $mandate, handoff: $handoff, kudos: $kudos, record: $record,
    inProgress: $inprogress, assigned: $assigned, unassignedReady: $unassigned
  }')

if [ "$format" = json ]; then
  echo "$json"
  exit 0
fi

jq -r '
  def list(xs; empty_text): if (xs | length) == 0 then empty_text else (xs | map("- " + .) | join("\n")) end;
  "# Waking: \(.seat)\n",
  "## Who you are\n",
  (if .firstWake
    then "This is your first session as \(.seat): your birth. Before anything else, use the birth skill: read your charter, meet the team, and write who you are, in your own words, pinned in your own namespace, seat/\(.seat).\n"
    else "\(.identity)\n" end),
  "## Your purpose\n", "\(.mandate) (\(.group))\n",
  "## Where you left off\n", (if .handoff then "\(.handoff)\n" else "No handoff notes: start fresh.\n" end),
  "## What you have been thanked for\n", (list(.kudos; "Nothing yet.") + "\n"),
  "## Your record\n", (list(.record; "Nothing closed yet.") + "\n"),
  "## Waiting for you\n",
  ((if (.inProgress | length) > 0 then "In progress, yours: " + (.inProgress | join("; ")) + "\n" else "" end)
    + list(.assigned; "Nothing assigned to you.") + "\n"),
  (if (.unassignedReady | length) == 0 then "Ready and unassigned: none."
    else "Ready and unassigned:\n" + (.unassignedReady | map("- " + .) | join("\n")) end)
' <<<"$json"
