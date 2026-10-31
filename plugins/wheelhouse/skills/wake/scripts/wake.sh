#!/usr/bin/env bash
# Wakes a Wheelhouse seat with purpose, not amnesia: who it is (its own
# identity, pinned in its ynm namespace), what it is for (its charter's
# mandate), where it left off (its handoff notes), what it has been thanked for
# (its Kudos), its record (what it closed lately) and what is waiting for it.
#
# First it syncs, so the seat wakes to what other machines and seats wrote:
# ynm's memory when the repository has a git remote, and the Beads work graph
# when it has a Dolt remote (bd sync pulls, then pushes). Each sync is skipped
# when there is no remote, gives up after 60 seconds, and never stops the
# wake; one that fails is named in the block. --no-sync skips both. It
# changes nothing else.
#
# The desk (the seat in the desk group) also wakes to the humans' inbox, first:
# what the seats have asked of the human at the desk and of the default human,
# and the notes left for them, from inbox.sh show (beside this script, as
# create-wheelhouse copies it). Other seats' wakes have no inbox.
#
# A seat's session-start hook runs it with --format text, and the seat starts
# with the block it prints. Run it from the Wheelhouse repository's root.
#
# Its session-end hook runs it with --end, which only syncs what the session
# wrote: memory (ynm sync) and the work graph (bd sync), each skipped without a
# remote and given up after 12 seconds. A full sync, not a push alone: when
# another seat has pushed since, a push alone is rejected until it merges. It prints
# {seat, push {memory, work: pushed|skipped|failed}} and nothing else.
#
# Output: JSON on stdout by default, {seat, group, firstWake, identity, mandate,
# handoff, handoffId, kudos, record, inProgress, assigned, unassignedReady (titles, most
# urgent first), sync {memory, work: synced|skipped|failed}, inbox (the desk's
# only: inbox.sh show's JSON, with errors when bd or ynm failed, or {error};
# null for other seats)}, or a Markdown
# block with --format text; with --end, the push above. Diagnostics on stderr.
# Exit codes: 0 printed, 1 bad args or no seat named, 2 not a Wheelhouse,
# 3 a tool it needs (jq, ynm, bd) is missing.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: wake.sh [--seat <name>] [--dir <wheelhouse repo>] [--format json|text] [--no-sync]
       wake.sh --end [--seat <name>] [--dir <wheelhouse repo>]

Syncs memory and work, then prints what a seat should know as it wakes.
--seat defaults to $BEADS_ACTOR; --dir to the current directory; --format to
json. --no-sync skips the sync. --end, for the session-end hook, only syncs
memory and work, and prints the result as JSON.
EOF
}

seat="${BEADS_ACTOR:-}"
dir="."
format="json"
sync=1
end=0
while [ $# -gt 0 ]; do
  case "$1" in
    --seat) [ $# -ge 2 ] || { usage >&2; exit 1; }; seat="$2"; shift 2 ;;
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --format) [ $# -ge 2 ] || { usage >&2; exit 1; }; format="$2"; shift 2 ;;
    --no-sync) sync=0; shift ;;
    --end) end=1; shift ;;
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

# A sync that hangs gives up after this many seconds (perl's alarm: macOS has
# no timeout).
limited() {
  local secs="$1"; shift
  if command -v perl >/dev/null 2>&1; then perl -e 'alarm shift; exec @ARGV' -- "$secs" "$@"; else "$@"; fi
}
hasgitremote() { git remote 2>/dev/null | grep -q .; }
hasdoltremote() { bd dolt remote list --json 2>/dev/null | jq -e '(.data? // .) | length > 0' >/dev/null 2>&1; }

# At the end of a session, sync what it wrote and stop.
if [ "$end" = 1 ]; then
  mempush=skipped
  workpush=skipped
  if hasgitremote; then
    if limited 12 ynm sync --quiet >/dev/null 2>&1; then mempush=pushed; else mempush=failed; fi
  fi
  if hasdoltremote; then
    if limited 12 bd sync >/dev/null 2>&1; then workpush=pushed; else workpush=failed; fi
  fi
  jq -nc --arg seat "$seat" --arg m "$mempush" --arg w "$workpush" '{seat: $seat, push: {memory: $m, work: $w}}'
  exit 0
fi

# Which seat this is.
entry=$(jq -c --arg s "$seat" '[.seats[] | select(.command == $s)][0] // empty' "$roster")
[ -n "$entry" ] || { echo "$seat is not a seat in the roster" >&2; exit 1; }
group=$(jq -r .group <<<"$entry")
charter="$(jq -r .harness <<<"$entry")/AGENTS.md"
mandate=$(sed -n 's/^\*\*Mandate:\*\* *//p' "$charter" 2>/dev/null | head -1)
[ -n "$mandate" ] || mandate=$(jq -r .mandate <<<"$entry")

# Sync first, so what follows is current.
memsync=skipped
worksync=skipped
if [ "$sync" = 1 ]; then
  if hasgitremote; then
    if limited 60 ynm sync --quiet >/dev/null 2>&1; then memsync=synced; else memsync=failed; fi
  fi
  if hasdoltremote; then
    if limited 60 bd sync >/dev/null 2>&1; then worksync=synced; else worksync=failed; fi
  fi
fi

# The seat's own memory lives in its namespace, seat/<name>.
recall() { ynm recall --namespace "seat/$seat" --subject "seat:$seat" --tags "$1" --limit "$2" --json 2>/dev/null || echo '[]'; }
identity=$(recall identity 1 | jq -c '[.[] | .content][0] // null')
notes=$(recall handoff 1)
handoff=$(jq -c '[.[] | .content][0] // null' <<<"$notes")
handoffid=$(jq -c '[.[] | .memoryId][0] // null' <<<"$notes")
kudos=$(recall kudos 5 | jq -c '[.[] | .content]')

# Its record and its work, from the graph.
# Beads' --json output is an array, or {"data": [...]} with BD_JSON_ENVELOPE=1 (the
# Beads 2.0 default); (.data? // .) reads either.
beads() { bd "$@" --json 2>/dev/null | jq -c '.data? // .' 2>/dev/null || echo '[]'; }
record=$(beads list --status closed --assignee "$seat" | jq -c 'sort_by(.updated_at) | reverse | .[:5] | map(.title)')
inprogress=$(beads list --status in_progress --assignee "$seat" | jq -c 'map(.title)')
assigned=$(beads ready --assignee "$seat" | jq -c 'map(select(.issue_type != "epic") | .title)')
unassigned=$(beads ready --unassigned | jq -c 'map(select(.issue_type != "epic")) | sort_by(.priority) | map(.title)')

# The desk's wake opens with the humans' inbox. inbox.sh sits beside this
# script in a Wheelhouse's scripts/, and in the work-graph skill otherwise.
inbox='null'
if [ "$group" = desk ]; then
  here=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
  inboxsh=""
  for f in "$here/inbox.sh" "scripts/inbox.sh" "$here/../../work-graph/scripts/inbox.sh"; do
    [ -f "$f" ] && { inboxsh="$f"; break; }
  done
  if [ -z "$inboxsh" ]; then
    inbox='{"error": "no inbox.sh beside wake.sh: copy it from the work-graph skill into scripts/"}'
  else
    # No temp file for its errors: a sandboxed seat may not write outside the
    # repository. On failure, run it again for the first line of its stderr.
    # When bd or ynm fails, show exits 3 but still prints JSON: what it could
    # read, with what failed in errors, which the block below names.
    shown=$(bash "$inboxsh" show --dir . 2>/dev/null)
    if [ -n "$shown" ] && jq -e . >/dev/null 2>&1 <<<"$shown"; then
      inbox=$(jq -c . <<<"$shown")
    else
      err=$(bash "$inboxsh" show --dir . 2>&1 >/dev/null | head -1)
      inbox=$(jq -nc --arg e "${err:-inbox.sh show failed}" '{error: $e}')
    fi
  fi
fi

json=$(jq -n --arg seat "$seat" --arg group "$group" --arg mandate "$mandate" \
  --argjson identity "$identity" --argjson handoff "$handoff" --argjson handoffid "$handoffid" --argjson kudos "$kudos" \
  --argjson record "$record" --argjson inprogress "$inprogress" --argjson assigned "$assigned" \
  --argjson unassigned "$unassigned" --arg memsync "$memsync" --arg worksync "$worksync" \
  --argjson inbox "$inbox" '{
    seat: $seat, group: $group, firstWake: ($identity == null), identity: $identity,
    mandate: $mandate, handoff: $handoff, handoffId: $handoffid, kudos: $kudos, record: $record,
    inProgress: $inprogress, assigned: $assigned, unassignedReady: $unassigned,
    sync: {memory: $memsync, work: $worksync}, inbox: $inbox
  }')

if [ "$format" = json ]; then
  echo "$json"
  exit 0
fi

jq -r '
  def list(xs; empty_text): if (xs | length) == 0 then empty_text else (xs | map("- " + .) | join("\n")) end;
  "# Waking: \(.seat)\n",
  ([if .sync.memory == "failed" then "memory (ynm sync)" else empty end,
    if .sync.work == "failed" then "the work graph (bd sync)" else empty end] as $failed
   | if ($failed | length) > 0
     then "**Not synced:** \($failed | join(" and ")) failed, so what follows may be out of date. Say so when you reply, and run the sync by hand before relying on it.\n"
     else empty end),
  (if .inbox == null then empty
   elif .inbox.error then "## For the humans\n\nThe inbox could not be read: \(.inbox.error). Say so when you reply; the doctor skill can help.\n"
   else
     def bead: "- \(.title)"
       + (if .ref then ": [\(.ref.short // .ref.url)](\(.ref.url))" else "" end)
       + " (\(.id), asked by \(.askedBy // "unknown"), unblocks \(.unblocks))";
     def note: "- \(.content) (note \(.memoryId))";
     "## For the humans\n",
     (if ((.inbox.errors // []) | length) > 0
      then "**The inbox could not be read in full:** \(.inbox.errors | join("; ")). Don'"'"'t say nothing is waiting: say what couldn'"'"'t be read when you reply, and what could; the doctor skill can help.\n"
      else empty end),
     (if .inbox.empty == true then "Nothing waiting for the humans.\n"
      else
        (.inbox.humans[] |
          "### \(.name) (\(.role))\n",
          (if .beads == null then "Their beads couldn'"'"'t be read.\n" else empty end),
          (if .notes == null then "Their notes couldn'"'"'t be read.\n" else empty end),
          (if .beads != null and .notes != null and (.beads | length) == 0 and (.notes | length) == 0 then "Nothing waiting.\n"
           else
             ((.beads // []) | map(select(.kind != "report"))) as $todo
             | ((.beads // []) | map(select(.kind == "report"))) as $reports
             | (if ($todo | length) > 0 then ($todo | map(bead) | join("\n")) + "\n" else empty end),
             (if ($reports | length) > 0 then "Reports:\n" + ($reports | map(bead) | join("\n")) + "\n" else empty end),
             (if (.notes // [] | length) > 0 then "Notes:\n" + (.notes | map(note) | join("\n")) + "\n" else empty end)
           end)),
        "Open your reply with this, before anything else (even who you are), naming each pull request or page by its short form as a Markdown link. Retire each note you relay, in the same turn, so it is not shown twice: `ynm forget --memory-id <its id> --reason \"relayed\"`.\n"
      end),
     (if .inbox.unknown then "You haven'"'"'t said who you are at this desk. Say \"it'"'"'s me, <name>\" to get your own inbox.\n" else empty end)
   end),
  "## Who you are\n",
  (if .firstWake
    then "This is your first session as \(.seat): your birth. Before anything else, use the birth skill: read your charter, meet the team, and write who you are, in your own words, pinned in your own namespace, seat/\(.seat).\n"
    else "\(.identity)\n" end),
  "## Your purpose\n", "\(.mandate) (\(.group))\n",
  "## Where you left off\n",
  (if .handoff
    then "\(.handoff)\n\nSay where you are picking up when you reply. Once you have, retire this note so it is not read twice: `ynm forget --memory-id \(.handoffId) --reason \"picked up\"`.\n"
    else "No handoff notes: start fresh.\n" end),
  "## What you have been thanked for\n",
  (if (.kudos | length) == 0 then "Nothing yet.\n"
    else list(.kudos; "") + "\n\nMention them in a line when you reply.\n" end),
  "## Your record\n", (list(.record; "Nothing closed yet.") + "\n"),
  "## Waiting for you\n",
  ((if (.inProgress | length) > 0 then "In progress, yours: " + (.inProgress | join("; ")) + "\n" else "" end)
    + list(.assigned; "Nothing assigned to you.") + "\n"),
  (if (.unassignedReady | length) == 0 then "Ready and unassigned: none."
    else "Ready and unassigned:\n" + (.unassignedReady | map("- " + .) | join("\n")) end)
' <<<"$json"
