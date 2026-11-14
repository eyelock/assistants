#!/usr/bin/env bash
# Wakes a Wheelhouse seat with purpose, not amnesia: who it is (its own
# identity, pinned in its ynm namespace), what it is for (its charter's
# mandate), where it left off (its handoff notes), what it has been thanked for
# (its Kudos), its record (what it closed lately), its latest close notes (the
# two lines it wrote on closing a bead) and what is waiting for it.
#
# Memory is read and synced through memory.sh (in the work-graph skill, beside
# the wake skill, where ynh installed it), which follows
# wheelhouse.json's "memory" key: ynm (the default) or Beads.
#
# First it syncs, through sync.sh (beside this script): memory with a git remote and the work
# graph with a Dolt remote (with Beads, one bd sync for both), each skipped without a remote, given
# up after WAKE_SYNC_SECS (default 45), never stopping the wake; one that fails is named in the
# block. --no-sync skips both. Then it gathers what the seat should know as JSON, and, with
# --format text, render-wake.jq (beside this script) lays that JSON out as the Markdown block. It
# changes nothing else. All three files travel together, in the wake skill's scripts/ folder, with
# wheelhouse-lib.sh from the work-graph skill.
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
#     a reason other than the bound, to read its error;
#   - the desk's ask.sh show --all: WAKE_ASK_SECS (default 30), twice when the first run fails for
#     a reason other than the bound (ask.sh bounds its own bd calls too).
# When bd is busy the block says plainly that the work graph couldn't be read (bd busy), and what
# to run by hand, instead of hanging or passing off nothing as "nothing waiting".
#
# The desk (the seat in the desk group) also wakes to the humans' inbox, first:
# what the seats have asked of the human at the desk and of the default human,
# and the notes left for them, from inbox.sh show (in the work-graph skill, beside
# the wake skill). Other seats' wakes have no inbox.
# It also wakes to every open ask, with its kind, asker, answering seat and age, from
# ask.sh show --all (in the work-graph skill, beside the wake skill), so a request left unanswered is seen; a seat's own asks already show
# under "Waiting for you".
#
# A seat's session-start hook runs it with --format text, and the seat starts
# with the block it prints. Run it from the Wheelhouse repository's root, or
# pass --dir <wheelhouse repo> from anywhere. The seat is --seat <name> or the
# name given bare, as in wake.sh gahan.
#
# Its session-end hook runs it with --end, which hands over to sync.sh --end: it syncs what the
# session wrote and prints {seat, push {memory, work: pushed|skipped|failed|timeout}} and, when a
# sync did not push, errors {memory, work}; see sync.sh for its budget. With --no-sync it syncs
# neither and reports both as skipped.
#
# Output: JSON on stdout by default, {seat, group, backend, firstWake, identity, mandate,
# handoff, handoffId, facts (the Wheelhouse's shared facts, at most 10), kudos, closeNotes [{bead, note}], record, inProgress, assigned,
# retro (the seat's own beads labelled retro, in progress and ready, kept apart from the two before it),
# unassignedReady (titles, most urgent first, retro beads skipped), workRead (false when bd was too slow to read), sync {memory, work: synced|skipped|failed}, inbox (the desk's
# only: inbox.sh show's JSON, with errors when bd or ynm failed, or {error};
# null for other seats), asks (the desk's only: ask.sh show --all's JSON, with errors when a bd
# read failed, or {error}; null for other seats), wakeFirst (the desk's only: the roster's ci-watcher and releaser seats as [{name, command, role, for}],
# [] when it has neither; null for other seats)}, or a Markdown
# block with --format text; with --end, the push above. Diagnostics on stderr.
# Exit codes: 0 printed, 1 bad args or no seat named, 2 not a Wheelhouse,
# 3 a tool it needs (jq, ynm, bd) is missing.
# shellcheck disable=SC2154  # fetch() assigns closedbeads, wipbeads, readybeads and openbeads by name (printf -v)
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

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/wheelhouse-lib.sh" "$here/../../work-graph/scripts/wheelhouse-lib.sh"; do
  # shellcheck source=../../work-graph/scripts/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found beside $0 or in the work-graph skill's scripts folder" >&2; exit 3; }
seat="${BEADS_ACTOR:-}"
positional=""
seat_flag=0
dir="."
format="json"
nosync=""
end=0
while [ $# -gt 0 ]; do
  case "$1" in
    --seat) [ $# -ge 2 ] || { usage >&2; exit 1; }; seat="$2"; seat_flag=1; shift 2 ;;
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --format) [ $# -ge 2 ] || { usage >&2; exit 1; }; format="$2"; shift 2 ;;
    --no-sync) nosync=1; shift ;;
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
for tool in jq bd; do need "$tool"; done
roster="$dir/$WL_ROSTER_REL"
[ -f "$roster" ] || { echo "not a Wheelhouse (no $roster)" >&2; exit 2; }
if [ -z "$seat" ]; then
  echo "no seat: pass --seat <name> (or the name bare), or set BEADS_ACTOR. The seats here: $(jq -r '[.seats[].command] | join(", ")' "$roster")" >&2
  usage >&2
  exit 1
fi
cd "$dir" || exit 2

# Where memory lives: wheelhouse.json's "memory", ynm when there is no file or no key.
backend=$(wl_backend .) || { echo "wheelhouse.json: memory must be \"ynm\" or \"beads\"" >&2; exit 2; }
if [ "$backend" = ynm ]; then need ynm; fi

bd_secs="${WAKE_BD_SECS:-20}"
inbox_secs="${WAKE_INBOX_SECS:-30}"; ask_secs="${WAKE_ASK_SECS:-30}"; ynm_secs="${WAKE_YNM_SECS:-10}"

# At the end of a session sync.sh syncs what it wrote and prints the result (--no-sync skips both).
if [ "$end" = 1 ]; then
  [ -f "$here/sync.sh" ] || { echo "no sync.sh beside wake.sh in the wake skill: reinstall the seat (ynh update)" >&2; exit 3; }
  exec bash "$here/sync.sh" --end --seat "$seat" --dir . ${nosync:+--no-sync}
fi

# Which seat this is.
entry=$(jq -c --arg s "$seat" '[.seats[] | select(.command == $s)][0] // empty' "$roster")
if [ -z "$entry" ]; then
  # A seat on trial is not in the roster until the trial ends, but its harness is on its
  # trial branch, checked out here: read it from there.
  if wl_is_trial_seat "$dir" "$seat"; then
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

# Sync first, so what follows is current: sync.sh prints {memory, work, remote}.
[ -f "$here/sync.sh" ] || { echo "no sync.sh beside wake.sh in the wake skill: reinstall the seat (ynh update)" >&2; exit 3; }
syncjson=$(bash "$here/sync.sh" --seat "$seat" --dir . ${nosync:+--no-sync}) || exit $?
memsync=$(jq -r .memory <<<"$syncjson")
worksync=$(jq -r .work <<<"$syncjson")
remote=$(jq -r .remote <<<"$syncjson")

# The seat's own memory, read through memory.sh: ynm namespace seat/<name>, or Beads keys seat/<name>/....
memorysh=""
for f in "$here/memory.sh" "$here/../../work-graph/scripts/memory.sh"; do
  [ -f "$f" ] && { memorysh="$f"; break; }
done
[ -n "$memorysh" ] || { echo "no memory.sh in the work-graph skill beside the wake skill: the seat needs skills/work-graph in its pick" >&2; exit 3; }
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
# fetch <var> <bd args>: reads into <var>, bounded. The first read that fails or gives up sets
# workfail and skips the rest, so a busy bd costs one wait, not one per read.
workfail=0
# A bd already known busy is not asked again.
[ "$worksync" != failed ] || [ "$remote" != busy ] || workfail=1
fetch() {
  local name="$1" out; shift
  if [ "$workfail" = 0 ] && out=$(limited "$bd_secs" bd "$@" --json 2>/dev/null) &&
    out=$(bd_data <<<"$out" 2>/dev/null) && [ -n "$out" ]; then
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
done < <(jq -r --arg own "retro:$seat" '.[] | select(((.labels // []) | index($own)) | not) | [.title, ((.notes // "") | [scan("PR: (https?://[^ \n]+)")[0]] | last // "")] | @tsv' <<<"$wipbeads" 2>/dev/null)
# The seat's own retro bead (labelled retro:<seat>) is its retro cycle, not its work: it is shown
# apart, and never comes before the bead the seat was woken or asked for. Other beads labelled retro
# (a review bead, a bead handed to the coach between rounds) are ordinary work for whoever holds
# them. Nobody picks up an unassigned retro bead.
own="retro:$seat"
notown='select(((.labels // []) | index($own)) | not)'
isown='select(((.labels // []) | index($own)))'
notretro='select(((.labels // []) | index("retro")) | not)'
fetch readybeads ready --assignee "$seat"
assigned=$(jq -c --arg own "$own" "map(select(.issue_type != \"epic\") | $notown | .title)" <<<"$readybeads" 2>/dev/null || echo '[]')
fetch openbeads ready --unassigned
unassigned=$(jq -c "map(select(.issue_type != \"epic\") | $notretro) | sort_by(.priority) | map(.title)" <<<"$openbeads" 2>/dev/null || echo '[]')
# When bd was busy these reads are empty, not absent: workRead says so, and the block names it.
retro=$( { echo "$wipbeads"; echo "$readybeads"; } |
  jq -sc --arg own "$own" "[.[][] | $isown | {id, title}] | unique_by(.id) | map(.title)" 2>/dev/null)
[ -n "$retro" ] || retro='[]'
workread=true; [ "$workfail" = 0 ] || workread=false

# The desk's wake opens with the humans' inbox. inbox.sh is in the work-graph skill, beside the wake skill.
inbox='null'
if [ "$group" = desk ]; then
  inboxsh=""
  for f in "$here/inbox.sh" "$here/../../work-graph/scripts/inbox.sh"; do
    [ -f "$f" ] && { inboxsh="$f"; break; }
  done
  if [ -z "$inboxsh" ]; then
    inbox='{"error": "no inbox.sh in the work-graph skill beside the wake skill: the desk needs skills/work-graph in its include"}'
  else
    # No temp file for its errors: a sandboxed seat may not write outside the
    # repository. On failure, run it again for the first line of its stderr.
    # When bd or ynm fails, show exits 3 but still prints JSON: what it could
    # read, with what failed in errors, which the block below names.
    shown=$(limited "$inbox_secs" bash "$inboxsh" show --dir . 2>/dev/null); inrc=$?
    if [ "$inrc" = 142 ]; then
      inbox=$(jq -nc --arg e "inbox.sh show gave up after ${inbox_secs}s (bd busy); run it yourself: bash $inboxsh show" '{error: $e}')
    elif [ -n "$shown" ] && jq -e . >/dev/null 2>&1 <<<"$shown"; then
      inbox=$(jq -c . <<<"$shown")
    else
      err=$(limited "$inbox_secs" bash "$inboxsh" show --dir . 2>&1 >/dev/null | head -1)
      inbox=$(jq -nc --arg e "${err:-inbox.sh show failed}" '{error: $e}')
    fi
  fi
fi

# The desk also wakes to a "Wake first" section after the inbox: the roster's CI-watcher and
# releaser seats (role ci-watcher, releaser), so the desk asks them for the open PRs and CI and
# the release in hand instead of checking GitHub itself. A Wheelhouse with neither prints none.
wakefirst='null'
if [ "$group" = desk ]; then
  wakefirst=$(jq -c '[.seats[] | select(.role == "ci-watcher" or .role == "releaser")
      | {name, command, role, for: (if .role == "ci-watcher" then "open PRs and CI" else "release in hand: next on the route" end)}]
      | sort_by(.role == "releaser")' "$roster" 2>/dev/null) || wakefirst='[]'
fi

# The desk's wake also lists every open ask. ask.sh is in the work-graph skill, beside the wake skill, as inbox.sh is.
# show exits 3 but still prints JSON when a bd read failed: what it could read, with errors.
asks='null'
if [ "$group" = desk ]; then
  asksh=""
  for f in "$here/ask.sh" "$here/../../work-graph/scripts/ask.sh"; do
    [ -f "$f" ] && { asksh="$f"; break; }
  done
  if [ -z "$asksh" ]; then
    asks='{"error": "no ask.sh in the work-graph skill beside the wake skill: the desk needs skills/work-graph in its include"}'
  else
    shown=$(limited "$ask_secs" bash "$asksh" show --all --dir . 2>/dev/null); askrc=$?
    if [ "$askrc" = 142 ]; then
      asks=$(jq -nc --arg e "ask.sh show gave up after ${ask_secs}s (bd busy); run it yourself: bash $asksh show --all" '{error: $e}')
    elif [ -n "$shown" ] && jq -e 'type == "object" and has("asks")' >/dev/null 2>&1 <<<"$shown"; then
      asks=$(jq -c . <<<"$shown")
    else
      err=$(limited "$ask_secs" bash "$asksh" show --all --dir . 2>&1 >/dev/null | head -1)
      asks=$(jq -nc --arg e "${err:-ask.sh show failed}" '{error: $e}')
    fi
  fi
fi

json=$(jq -n --arg seat "$seat" --arg group "$group" --arg mandate "$mandate" \
  --argjson identity "$identity" --argjson handoff "$handoff" --argjson handoffid "$handoffid" --argjson kudos "$kudos" --argjson closenotes "$closenotes" --argjson facts "$facts" --arg backend "$backend" \
  --argjson record "$record" --argjson inprogress "$inprogress" --argjson assigned "$assigned" --argjson retro "$retro" \
  --argjson unassigned "$unassigned" --arg memsync "$memsync" --arg worksync "$worksync" --argjson workread "$workread" \
  --argjson inbox "$inbox" --argjson asks "$asks" --argjson wakefirst "$wakefirst" '{
    seat: $seat, group: $group, backend: $backend, firstWake: ($identity == null), identity: $identity,
    mandate: $mandate, handoff: $handoff, handoffId: $handoffid, facts: $facts, kudos: $kudos, closeNotes: $closenotes, record: $record,
    inProgress: $inprogress, assigned: $assigned, retro: $retro, unassignedReady: $unassigned, workRead: $workread,
    sync: {memory: $memsync, work: $worksync}, inbox: $inbox, asks: $asks, wakeFirst: $wakefirst
  }')

if [ "$format" = json ]; then
  echo "$json"
  exit 0
fi

[ -f "$here/render-wake.jq" ] || { echo "no render-wake.jq beside wake.sh in the wake skill: reinstall the seat (ynh update)" >&2; exit 3; }
jq -r --arg memsh "$memorysh" -f "$here/render-wake.jq" <<<"$json"
