#!/usr/bin/env bash
# Wakes a Wheelhouse seat with purpose, not amnesia: who it is (its own
# identity, pinned in its ynm namespace), what it is for (its charter's
# mandate), where it left off (its handoff notes), what it has been thanked for
# (its Kudos), its record (what it closed lately), its latest close notes (the
# two lines it wrote on closing a bead) and what is waiting for it.
#
# Memory is read and synced through memory.sh (beside this script, as
# create-wheelhouse copies it, or in the work-graph skill), which follows
# wheelhouse.json's "memory" key: ynm (the default) or Beads.
#
# First it syncs, so the seat wakes to what other machines and seats wrote.
# With ynm, memory syncs when the repository has a git remote and the Beads work
# graph when it has a Dolt remote. With Beads, memory and work are one database
# and one bd sync, with one result for both. Each sync is skipped when there is
# no remote, gives up after WAKE_SYNC_SECS (default 45), and never stops the wake; one that
# fails is named in the block. --no-sync skips both. It changes nothing else.
#
# Every bd, memory.sh, inbox.sh and gh call is bounded, so a wake never hangs when other seats
# hold bd's lock. The bounds are per call; there is no total, because the number of calls changes
# with the path (a gh pr view runs once per in-progress bead with a PR, and the inbox can run
# twice). The bounds:
#   - ynm sync and bd sync: WAKE_SYNC_SECS (default 45) each, and the Dolt-remote check that comes
#     before bd sync: WAKE_SYNC_SECS too;
#   - the four bd reads (closed, in progress, ready for the seat, ready unassigned): WAKE_BD_SECS
#     (default 20) each, and the first one that gives up ends the rest, so a busy bd costs one
#     wait, and none at all when the remote check already found it busy;
#   - the two memory.sh recalls (the seat's own, and the shared facts) and each gh pr view:
#     WAKE_YNM_SECS (default 10) each;
#   - the desk's inbox.sh show: WAKE_INBOX_SECS (default 30), twice when the first run fails for
#     a reason other than the bound, to read its error.
# When bd is busy the block says plainly that the work graph couldn't be read (bd busy), and what
# to run by hand, instead of hanging or passing off nothing as "nothing waiting".
#
# The desk (the seat in the desk group) also wakes to the humans' inbox, first:
# what the seats have asked of the human at the desk and of the default human,
# and the notes left for them, from inbox.sh show (beside this script, as
# create-wheelhouse copies it). Other seats' wakes have no inbox.
#
# A seat's session-start hook runs it with --format text, and the seat starts
# with the block it prints. Run it from the Wheelhouse repository's root, or
# pass --dir <wheelhouse repo> from anywhere. The seat is --seat <name> or the
# name given bare, as in wake.sh gahan.
#
# Its session-end hook runs it with --end, which only syncs what the session
# wrote: memory (ynm sync) and the work graph (bd sync), each skipped without a
# remote and run side by side (with Beads, memory and work are one bd sync, reported for both; the Dolt-remote check is inside the work sync's budget, a third of it) and given up after 25 seconds, inside the 30-second session-end hook
# (WHEELHOUSE_END_SYNC_SECS sets the budget, at most 28). A full sync, not a push alone: when
# another seat has pushed since, a push alone is rejected until it merges. It prints
# {seat, push {memory, work: pushed|skipped|failed|timeout}} and, when a sync did not
# push, errors {memory, work}: its exit code and the first line it printed. With
# --no-sync it syncs neither and reports both as skipped.
#
# Output: JSON on stdout by default, {seat, group, backend, firstWake, identity, mandate,
# handoff, handoffId, facts (the Wheelhouse's shared facts, at most 10), kudos, closeNotes [{bead, note}], record, inProgress, assigned, unassignedReady (titles, most
# urgent first), workRead (false when bd was too slow to read), sync {memory, work: synced|skipped|failed}, inbox (the desk's
# only: inbox.sh show's JSON, with errors when bd or ynm failed, or {error};
# null for other seats)}, or a Markdown
# block with --format text; with --end, the push above. Diagnostics on stderr.
# Exit codes: 0 printed, 1 bad args or no seat named, 2 not a Wheelhouse,
# 3 a tool it needs (jq, ynm, bd) is missing.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: wake.sh [--seat <name>] [--dir <wheelhouse repo>] [--format json|text]
               [--no-sync]
       wake.sh <name> [--dir <wheelhouse repo>] [--format json|text]
               [--no-sync]
       wake.sh --end [--seat <name> | <name>] [--dir <wheelhouse repo>]
               [--no-sync]

Syncs memory and work, then prints what a seat should know as it wakes.
The seat is --seat <name>, or the seat's name given bare; it defaults to
$BEADS_ACTOR, and without any of them the script stops and lists the roster's
seats. Run it as bash <wheelhouse>/scripts/wake.sh, and pass --dir <wheelhouse>
when the current directory is not the Wheelhouse's root. --dir defaults to the
current directory; --format to json. --no-sync skips the sync. --end, for the
session-end hook, only syncs memory and work, and prints the result as JSON;
--end --no-sync syncs neither and reports both as skipped.
EOF
}

seat="${BEADS_ACTOR:-}"
positional=""
seat_flag=0
dir="."
format="json"
sync=1
end=0
while [ $# -gt 0 ]; do
  case "$1" in
    --seat) [ $# -ge 2 ] || { usage >&2; exit 1; }; seat="$2"; seat_flag=1; shift 2 ;;
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --format) [ $# -ge 2 ] || { usage >&2; exit 1; }; format="$2"; shift 2 ;;
    --no-sync) sync=0; shift ;;
    --end) end=1; shift ;;
    --help | -h) usage; exit 0 ;;
    -*) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
    *)
      # A bare seat name, such as wake.sh hynde: the same as --seat hynde, once.
      [ -z "$positional" ] || { echo "more than one seat named: $positional and $1" >&2; usage >&2; exit 1; }
      positional="$1"; shift ;;
  esac
done
if [ -n "$positional" ]; then
  [ "$seat_flag" != 1 ] || [ "$seat" = "$positional" ] || { echo "two different seats named: --seat $seat and $positional" >&2; usage >&2; exit 1; }
  seat="$positional"
fi
case "$format" in json | text) ;; *) echo "--format must be json or text" >&2; exit 1 ;; esac
for tool in jq bd; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required" >&2; exit 3; }
done
roster="$dir/skills/roster/assets/roster.json"
[ -f "$roster" ] || { echo "not a Wheelhouse (no $roster)" >&2; exit 2; }
if [ -z "$seat" ]; then
  echo "no seat: pass --seat <name> (or the name bare), or set BEADS_ACTOR. The seats here: $(jq -r '[.seats[].command] | join(", ")' "$roster")" >&2
  usage >&2
  exit 1
fi
cd "$dir" || exit 2

# Where memory lives: wheelhouse.json's "memory", ynm when there is no file or no key.
backend=ynm
if [ -f wheelhouse.json ]; then
  backend=$(jq -r '.memory // "ynm"' wheelhouse.json 2>/dev/null) || backend=""
  case "$backend" in ynm | beads) ;; *) echo "wheelhouse.json: memory must be \"ynm\" or \"beads\"" >&2; exit 2 ;; esac
fi
if [ "$backend" = ynm ]; then
  command -v ynm >/dev/null 2>&1 || { echo "ynm is required" >&2; exit 3; }
fi

# A command that hangs gives up after this many seconds (perl's alarm: macOS has
# no timeout).
limited() {
  local secs="$1"; shift
  # The command runs in its own process group, and the whole group is killed on the alarm: a bd
  # that has spawned a child would otherwise hold the output pipe open past the limit. Exit 142.
  if command -v perl >/dev/null 2>&1; then
    perl -e 'my $s = shift; setpgrp(0, 0); my $p = fork; if (!$p) { exec @ARGV; exit 127 }
      $SIG{ALRM} = sub { $SIG{TERM} = "IGNORE"; kill "TERM", -$$; exit 142 };
      alarm $s; waitpid($p, 0); exit(($? & 127) ? 128 + ($? & 127) : $? >> 8)' -- "$secs" "$@"
  else "$@"; fi
}
hasgitremote() { git remote 2>/dev/null | grep -q .; }
bd_secs="${WAKE_BD_SECS:-20}"; sync_secs="${WAKE_SYNC_SECS:-45}"
inbox_secs="${WAKE_INBOX_SECS:-30}"; ynm_secs="${WAKE_YNM_SECS:-10}"
# doltremote [secs] sets remote to yes, no, or busy: a check that gave up (exit 142) or failed is
# not "no remote", it is a bd that cannot be reached, which the callers report as a failed sync.
remote=no
doltremote() {
  local secs="${1:-$sync_secs}" out rc
  out=$(limited "$secs" bd dolt remote list --json 2>/dev/null); rc=$?
  if [ "$rc" != 0 ]; then remote=busy
  elif jq -e '(.data? // .) | length > 0' >/dev/null 2>&1 <<<"$out"; then remote=yes
  else remote=no; fi
}

# At the end of a session, sync what it wrote and stop (--no-sync skips both).
if [ "$end" = 1 ]; then
  mempush=skipped
  workpush=skipped
  memerr=""
  workerr=""
  # The two syncs run side by side, each given the same budget, so the worst case is the budget
  # itself, not twice it. The session-end hook gives wake.sh 30 seconds and kills it after that,
  # before the JSON below prints, so the budget stays under it: 25 seconds by default, never more
  # than 28 (WHEELHOUSE_END_SYNC_SECS lowers or raises it within that).
  budget="${WHEELHOUSE_END_SYNC_SECS:-25}"
  case "$budget" in '' | *[!0-9]*) budget=25 ;; esac
  [ "$budget" -gt 28 ] && budget=28
  [ "$budget" -lt 1 ] && budget=1
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/wake-end.XXXXXX")
  # Runs one sync with the budget and keeps its output in <tmp>/<name>.rc and .err: the exit code
  # (142 when the alarm killed it) and "exit N: first line".
  endsync() {
    local name="$1"; shift
    local rc first
    limited "$budget" "$@" >"$tmp/$name.out" 2>&1
    rc=$?
    echo "$rc" >"$tmp/$name.rc"
    if [ "$rc" != 0 ]; then
      first=$(grep -m1 . "$tmp/$name.out" 2>/dev/null | cut -c1-200)
      printf '%s' "exit $rc${first:+: $first}" >"$tmp/$name.err"
    fi
  }
  # The work sync, with its Dolt-remote check in the same budget (a third for the check, the rest
  # for the sync), run in the background beside the memory sync. A check that gave up or failed
  # is a failed sync, not "no remote".
  endwork() {
    local check=$(( budget / 3 ))
    [ "$check" -ge 1 ] || check=1
    doltremote "$check"
    if [ "$remote" = busy ]; then
      echo 142 >"$tmp/work.rc"; printf '%s' "exit 142: the Dolt-remote check gave up or failed (bd busy)" >"$tmp/work.err"
    elif [ "$remote" = yes ]; then
      endsync work bd sync
    fi
  }
  # With Beads, memory and work are one database: one bd sync, and its result is both.
  if [ "$backend" = ynm ]; then
    if [ "$sync" = 1 ] && hasgitremote; then endsync mem ynm sync --quiet & fi
    if [ "$sync" = 1 ]; then endwork & fi
  else
    if [ "$sync" = 1 ]; then endwork & fi
  fi
  wait
  if [ "$backend" = beads ]; then
    for f in rc err; do [ -f "$tmp/work.$f" ] && cp "$tmp/work.$f" "$tmp/mem.$f"; done
  fi
  # <var> becomes pushed, timeout or failed from the sync's exit code; <errvar> its error text.
  endresult() {
    local name="$1" var="$2" errvar="$3" rc
    [ -f "$tmp/$name.rc" ] || return 0
    rc=$(cat "$tmp/$name.rc")
    if [ "$rc" = 0 ]; then printf -v "$var" pushed
    else
      if [ "$rc" = 142 ]; then printf -v "$var" timeout; else printf -v "$var" failed; fi
      printf -v "$errvar" '%s' "$(cat "$tmp/$name.err")"
    fi
  }
  endresult mem mempush memerr
  endresult work workpush workerr
  rm -rf "$tmp"
  jq -nc --arg seat "$seat" --arg m "$mempush" --arg w "$workpush" --arg me "$memerr" --arg we "$workerr" \
    '{seat: $seat, push: {memory: $m, work: $w}} + (if $me != "" or $we != "" then {errors: ({memory: $me, work: $we} | with_entries(select(.value != "")))} else {} end)'
  exit 0
fi

# Which seat this is.
entry=$(jq -c --arg s "$seat" '[.seats[] | select(.command == $s)][0] // empty' "$roster")
if [ -z "$entry" ]; then
  # A seat on trial is not in the roster until the trial ends, but its harness is on its
  # trial branch, checked out here: read it from there.
  if [ -f "$dir/harnesses/$seat/AGENTS.md" ]; then
    entry=$(jq -nc --arg s "$seat" '{command: $s, group: "trial", harness: ("harnesses/" + $s), mandate: ""}')
  else
    echo "$seat is not a seat in the roster, and there is no harnesses/$seat/AGENTS.md here (a seat on trial has one on its branch)" >&2
    exit 1
  fi
fi
group=$(jq -r .group <<<"$entry")
charter="$dir/$(jq -r .harness <<<"$entry")/AGENTS.md"
# The Mandate is a paragraph: from its "**Mandate:**" line to the next blank line, joined on one line.
mandate=$(awk '
  found && /^[[:space:]]*$/ { exit }
  found { sub(/^[[:space:]]+/, ""); printf " %s", $0; next }
  /^\*\*Mandate:\*\*/ { found = 1; sub(/^\*\*Mandate:\*\* */, ""); printf "%s", $0 }
' "$charter" 2>/dev/null)
[ -n "$mandate" ] || mandate=$(jq -r .mandate <<<"$entry")

# Sync first, so what follows is current.
memsync=skipped
worksync=skipped
if [ "$sync" = 1 ]; then
  if [ "$backend" = ynm ]; then
    if hasgitremote; then
      if limited "$sync_secs" ynm sync --quiet >/dev/null 2>&1; then memsync=synced; else memsync=failed; fi
    fi
    doltremote
    if [ "$remote" = busy ]; then worksync=failed
    elif [ "$remote" = yes ]; then
      if limited "$sync_secs" bd sync >/dev/null 2>&1; then worksync=synced; else worksync=failed; fi
    fi
  else
    # Memory and work are one database: one sync, one result for both.
    doltremote
    if [ "$remote" = busy ]; then memsync=failed
    elif [ "$remote" = yes ]; then
      if limited "$sync_secs" bd sync >/dev/null 2>&1; then memsync=synced; else memsync=failed; fi
    fi
    worksync=$memsync
  fi
fi

# The seat's own memory, read through memory.sh: ynm namespace seat/<name>, or Beads keys seat/<name>/....
here=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
memorysh=""
for f in "$here/memory.sh" "scripts/memory.sh" "$here/../../work-graph/scripts/memory.sh"; do
  [ -f "$f" ] && { memorysh="$f"; break; }
done
[ -n "$memorysh" ] || { echo "no memory.sh beside wake.sh: copy it from the work-graph skill into scripts/" >&2; exit 3; }
# A recall that fails reads as nothing; memory.sh says why on stderr, which the wake does not show.
# Bounded: a recall that gives up reads the same.
recall() {
  local out
  out=$(limited "$ynm_secs" bash "$memorysh" recall --dir . "$@" 2>/dev/null) && out=$(jq -c . <<<"$out" 2>/dev/null) && [ -n "$out" ] && echo "$out" || echo '[]'
}
# One recall for the whole seat (each memory.sh recall asks the store afresh, about 3s on ynm),
# split by kind here. Newest first, so each slice keeps the latest.
mine=$(recall --seat "$seat" --limit 200)
of() { jq -c --arg k "$1" '[.[] | select(.kind == $k)]' <<<"$mine"; }
identity=$(of identity | jq -c '[.[] | .text][0] // null')
notes=$(of handoff | jq -c '.[:1]')
handoff=$(jq -c '[.[] | .text][0] // null' <<<"$notes")
handoffid=$(jq -c '[.[] | .id][0] // null' <<<"$notes")
kudos=$(of kudos | jq -c '.[:5] | [.[] | .text]')
# Close notes are about a bead, not the seat: the latest three, newest first.
closenotes=$(of close-note | jq -c '.[:3] | map({bead: .bead, note: .text})')
# What the whole Wheelhouse knows (shared facts), capped.
facts=$(recall --shared --limit 10 | jq -c '[.[] | .text]')

# Its record and its work, from the graph.
# Beads' --json output is an array, or {"data": [...]} with BD_JSON_ENVELOPE=1 (the
# Beads 2.0 default); (.data? // .) reads either.
# fetch <var> <bd args>: reads into <var>, bounded. The first read that fails or gives up sets
# workfail and skips the rest, so a busy bd costs one wait, not one per read.
workfail=0
# A bd already known busy is not asked again.
[ "$worksync" != failed ] || [ "$remote" != busy ] || workfail=1
fetch() {
  local name="$1" out; shift
  if [ "$workfail" = 0 ] && out=$(limited "$bd_secs" bd "$@" --json 2>/dev/null) &&
    out=$(jq -c '.data? // .' <<<"$out" 2>/dev/null) && [ -n "$out" ]; then
    printf -v "$name" '%s' "$out"
  else
    workfail=1; printf -v "$name" '[]'
  fi
}
fetch closedbeads list --status closed --assignee "$seat"
record=$(jq -c 'sort_by(.updated_at) | reverse | .[:5] | map(.title)' <<<"$closedbeads" 2>/dev/null || echo '[]')
# A bead whose notes carry "PR: <url>" (open-pr.sh writes it) and whose pull request is open is
# waiting on a review or a merge, not work to carry on with: its title is marked "(waiting on PR
# <url>)". If gh cannot say, the mark says the state is unknown rather than guessing.
inprogress='[]'
fetch wipbeads list --status in_progress --assignee "$seat"
while IFS=$'\t' read -r title prurl; do
  [ -n "$title" ] || continue
  if [ -n "$prurl" ]; then
    state=$(limited "$ynm_secs" gh pr view "$prurl" --json state --jq .state 2>/dev/null || true)
    case "$state" in
      OPEN) title="$title (waiting on PR $prurl)" ;;
      MERGED|CLOSED) ;;
      *) title="$title (PR noted: $prurl, state unknown)" ;;
    esac
  fi
  inprogress=$(jq -c --arg t "$title" '. + [$t]' <<<"$inprogress")
done < <(jq -r '.[] | [.title, ((.notes // "") | [scan("PR: (https?://[^ \n]+)")[0]] | last // "")] | @tsv' <<<"$wipbeads" 2>/dev/null)
fetch readybeads ready --assignee "$seat"
assigned=$(jq -c 'map(select(.issue_type != "epic") | .title)' <<<"$readybeads" 2>/dev/null || echo '[]')
fetch openbeads ready --unassigned
unassigned=$(jq -c 'map(select(.issue_type != "epic")) | sort_by(.priority) | map(.title)' <<<"$openbeads" 2>/dev/null || echo '[]')
workread=true; [ "$workfail" = 0 ] || workread=false

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
    shown=$(limited "$inbox_secs" bash "$inboxsh" show --dir . 2>/dev/null); inrc=$?
    if [ "$inrc" = 142 ]; then
      inbox=$(jq -nc --arg e "inbox.sh show gave up after ${inbox_secs}s (bd busy); run it yourself: bash scripts/inbox.sh show" '{error: $e}')
    elif [ -n "$shown" ] && jq -e . >/dev/null 2>&1 <<<"$shown"; then
      inbox=$(jq -c . <<<"$shown")
    else
      err=$(limited "$inbox_secs" bash "$inboxsh" show --dir . 2>&1 >/dev/null | head -1)
      inbox=$(jq -nc --arg e "${err:-inbox.sh show failed}" '{error: $e}')
    fi
  fi
fi

json=$(jq -n --arg seat "$seat" --arg group "$group" --arg mandate "$mandate" \
  --argjson identity "$identity" --argjson handoff "$handoff" --argjson handoffid "$handoffid" --argjson kudos "$kudos" --argjson closenotes "$closenotes" --argjson facts "$facts" --arg backend "$backend" \
  --argjson record "$record" --argjson inprogress "$inprogress" --argjson assigned "$assigned" \
  --argjson unassigned "$unassigned" --arg memsync "$memsync" --arg worksync "$worksync" --argjson workread "$workread" \
  --argjson inbox "$inbox" '{
    seat: $seat, group: $group, backend: $backend, firstWake: ($identity == null), identity: $identity,
    mandate: $mandate, handoff: $handoff, handoffId: $handoffid, facts: $facts, kudos: $kudos, closeNotes: $closenotes, record: $record,
    inProgress: $inprogress, assigned: $assigned, unassignedReady: $unassigned, workRead: $workread,
    sync: {memory: $memsync, work: $worksync}, inbox: $inbox
  }')

if [ "$format" = json ]; then
  echo "$json"
  exit 0
fi

jq -r '
  def retire(id; why): if .backend == "beads" then "bd forget -- \(id)" else "ynm forget --memory-id \(id) --reason \"\(why)\"" end;
  def list(xs; empty_text): if (xs | length) == 0 then empty_text else (xs | map("- " + .) | join("\n")) end;
  "# Waking: \(.seat)\n",
  ([if .sync.memory == "failed" then (if .backend == "beads" then "memory and the work graph (bd sync)" else "memory (ynm sync)" end) else empty end,
    if .sync.work == "failed" and .backend != "beads" then "the work graph (bd sync)" else empty end] as $failed
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
        "Open your reply with this, before anything else (even who you are), naming each pull request or page by its short form as a Markdown link. Retire each note you relay, in the same turn, so it is not shown twice: `bash scripts/memory.sh forget --id <its memoryId> --reason relayed`.\n"
      end),
     (if .inbox.you == null then "This is the default human'"'"'s inbox, and the desk treats the human at the desk as them. After the inbox, tell the human so in your reply, and that they can name themselves for this session (\"it'"'"'s me, <name>\") to see their own inbox instead; nothing is saved. Always say it: do not leave it out because the inbox is empty or you have much else to report.\n" else empty end)
   end),
  "## Who you are\n",
  (if .firstWake
    then "This is your first session as \(.seat): your birth. Before anything else, use the birth skill: read your charter, meet the team, and write who you are, in your own words, pinned in your own namespace, seat/\(.seat).\n"
    else "\(.identity)\n" end),
  "## Your purpose\n", "\(.mandate) (\(.group))\n",
  "## Where you left off\n",
  (if .handoff
    then "\(.handoff)\n\nSay where you are picking up when you reply. Once you have, retire this note so it is not read twice: `\(retire(.handoffId; "picked up"))`.\n"
    else "No handoff notes: start fresh.\n" end),
  (if (.facts | length) == 0 then empty
    else "## What the Wheelhouse knows\n", (.facts | map("- " + (. | gsub("\n"; " / "))) | join("\n")) + "\n"
    end),
  "## What you have been thanked for\n",
  (if (.kudos | length) == 0 then "Nothing yet.\n"
    else list(.kudos; "") + "\n\nMention them in a line when you reply.\n" end),
  (if .workRead == false
   then "**The work graph couldn'"'"'t be read (bd busy):** your record, your work in progress and what is ready are missing, not empty. Say so when you reply, and run `bd list --status in_progress --assignee \(.seat)`, `bd ready --assignee \(.seat)` and `bd ready --unassigned` yourself.\n"
   else empty end),
  "## Your record\n", (list(.record; "Nothing closed yet.") + "\n"),
  (if (.closeNotes | length) == 0 then empty
    else "## Your close notes\n", (.closeNotes | map("- " + (.bead // "?") + ": " + (.note | gsub("\n"; " / "))) | join("\n")) + "\n"
    end),
  "## Waiting for you\n",
  (if .workRead == false then "Couldn'"'"'t read the work graph (bd busy); run the bd commands above yourself.\n" else
  ((if (.inProgress | length) > 0 then "In progress, yours: " + (.inProgress | join("; ")) + "\n" else "" end)
    + list(.assigned; "Nothing assigned to you.") + "\n"),
  (if (.unassignedReady | length) == 0 then "Ready and unassigned: none."
    else "Ready and unassigned:\n" + (.unassignedReady | map("- " + .) | join("\n")) end) end)
' <<<"$json"
