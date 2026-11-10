#!/usr/bin/env bash
# Seat-to-seat asks: how one seat asks another for something, in the work graph,
# so the ask is recorded, shown at the answering seat's wake and can be flagged
# when it is left unanswered. It sits beside inbox.sh, which stays about humans.
#
# An ask is a bead labelled `ask` plus one kind label, `ask:<kind>`:
#
#   question  something the asker needs to know. Assigned to the seat that
#             answers it; blocks the asker's bead when --blocks says so.
#   request   something the asker needs done. Same shape as a question.
#   return    a bead a seat hands back (outside its charter, unclear, unsafe).
#             It is the bead itself, re-assigned to the desk: no new bead.
#   report    something the desk should read, which needs no answer. Assigned to
#             the desk, blocks nothing; the desk closes it once it has read it.
#
# The desk is the roster's seat in the `desk` group; its command is the
# Wheelhouse's name. `--to desk` (or its command) means it.
#
#   open      creates the ask, as the asking seat, and prints the session address
#             of the seat that answers it, for the asking seat to nudge.
#   answer    the answering seat comments the answer and re-assigns the ask to
#             the seat that asked, who closes it (which unblocks its bead).
#   return    comments why, releases the seat's claim on a bead and re-assigns it
#             to the desk, labelled ask and ask:return.
#             It replaces any other kind label, so a returned ask is only a return.
#   show      the open asks for a seat, or every seat's with --all.
#
# Run it from the Wheelhouse repository's root, or pass --dir.
# Output: JSON on stdout; diagnostics on stderr.
# Exit codes: 0 done, 1 bad args or refused, 2 not a Wheelhouse, 3 a tool it needs
# (jq, bd) is missing or failed. Every bd call is bounded (ASK_BD_TIMEOUT seconds,
# default 20). show exits 3 when a read failed, and still prints what it could read,
# with what failed in errors.
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: ask.sh open --to <seat|desk> --kind question|request|report --title <title> --from <seat>
                   [--blocks <bead>] [--repo <repo>] [--description <text>] [--priority 0-4]
       ask.sh answer <ask> --text <answer> --from <seat>
       ask.sh return <bead> --reason <text> --from <seat>
       ask.sh show [--seat <command>] [--all] [--older-than <duration>]

Common: --dir <wheelhouse repo> (default: the current directory).
--from defaults to $BEADS_ACTOR; every command that changes the graph needs it, as a
seat in the roster or a seat on trial (harnesses/<command>/AGENTS.md on this branch).

open      Creates a bead labelled ask and ask:<kind>, assigned to --to (a seat's command,
          or desk), created as --from. --blocks makes the given bead wait on this one
          (a question or request only), and --repo labels it repo:<repo>; without --repo it
          takes the repo: label of the --blocks bead. A report is assigned to the desk and
          blocks nothing: --to defaults to the desk, and another seat or --blocks is
          refused. A question or request needs --to, which may not be --from.
          Prints {id, to, askedBy, kind, blocks, repo, session, nudge}. session is the
          address of the seat that answers it: <wheelhouse>-<command>, or just <wheelhouse>
          for the desk. Where the vendor can message a live session (Claude's SendMessage),
          send one line there and, if it fails or no session is live, say so on the ask; the
          script cannot send it, because that is a tool of the agent, not of the shell.
answer    Comments --text on the ask and re-assigns it to its asker (the bead's creator).
          Only the seat the ask is assigned to answers it, and only a question or request.
          The asker reads the answer at its next wake, under "Waiting for you", and closes
          the ask. Prints {id, answeredBy, to}.
return    Comments --reason on the bead, releases --from's claim on it (status open) and
          re-assigns it to the desk, labelled ask and ask:return, and drops any other
          kind label (ask:question, ask:request), so the desk sees a return. No new bead is made. The
          seat must hold the bead (be its assignee); a report and the desk's own beads are
          refused. Prints {id, returnedBy, to}.
show      Prints {seat, all, olderThanSeconds, count, asks: [{id, title, kind, askedBy,
          assignee, answered, createdAt, ageSeconds, age, priority, blocks}], errors}, oldest
          first. By default the open asks assigned to --seat (default: $BEADS_ACTOR); --all
          for every seat's. answered is true for a question or request the answering seat
          has handed back to its asker. --older-than keeps asks at least that old (a number
          and one of s, m, h or d: 30m, 24h, 2d). A read that fails is never an empty list:
          errors says what failed and show exits 3.
USAGE
}

die() { echo "$2" >&2; exit "$1"; }

[ $# -gt 0 ] || { usage >&2; exit 1; }
cmd="$1"; shift
case "$cmd" in
  open | answer | return | show) ;;
  --help | -h) usage; exit 0 ;;
  *) echo "unknown command: $cmd" >&2; usage >&2; exit 1 ;;
esac

dir="."
to=""; kind=""; title=""; from="${BEADS_ACTOR:-}"; blocks=""; repo=""; description=""; priority=""
text=""; reason=""; seat=""; all=0; older=""; id=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --all) all=1; shift ;;
    --dir | --to | --kind | --title | --from | --blocks | --repo | --description | --priority | --text | --reason | --seat | --older-than)
      [ $# -ge 2 ] || { usage >&2; exit 1; }
      v="$2"
      case "$1" in
        --dir) dir="$v" ;; --to) to="$v" ;; --kind) kind="$v" ;; --title) title="$v" ;; --from) from="$v" ;;
        --blocks) blocks="$v" ;; --repo) repo="$v" ;; --description) description="$v" ;; --priority) priority="$v" ;;
        --text) text="$v" ;; --reason) reason="$v" ;; --seat) seat="$v" ;; --older-than) older="$v" ;;
      esac
      shift 2 ;;
    -*) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
    *)
      # answer and return take the bead bare: ask.sh answer <ask> --text <answer>
      if { [ "$cmd" = answer ] || [ "$cmd" = return ]; } && [ -z "$id" ]; then id="$1"; shift
      else echo "unknown argument: $1" >&2; usage >&2; exit 1; fi ;;
  esac
done

command -v jq >/dev/null 2>&1 || die 3 "jq is required"
roster="$dir/skills/roster/assets/roster.json"
[ -f "$roster" ] || die 2 "not a Wheelhouse (no $roster)"
command -v bd >/dev/null 2>&1 || die 3 "bd is required"
cd "$dir" || exit 2
roster=skills/roster/assets/roster.json

# Every bd call is bounded, so a stuck database can't hold a seat. bd runs in its own process
# group and the whole group is killed on the alarm (exit 142): a child bd started would otherwise
# hold the output pipe open past the limit. The same as wake.sh's limited().
bd_secs="${ASK_BD_TIMEOUT:-20}"
case "$bd_secs" in '' | *[!0-9]*) bd_secs=20 ;; esac
bdb() {
  if command -v perl >/dev/null 2>&1; then
    perl -e 'my $s = shift; setpgrp(0, 0); my $p = fork; if (!$p) { exec @ARGV; exit 127 }
      $SIG{ALRM} = sub { $SIG{TERM} = "IGNORE"; kill "TERM", -$$; exit 142 };
      alarm $s; waitpid($p, 0); exit(($? & 127) ? 128 + ($? & 127) : $? >> 8)' -- "$bd_secs" bd "$@"
  else bd "$@"; fi
}

# Beads' --json output is an array or object, or {"data": ...} with BD_JSON_ENVELOPE=1.
first='(.data? // .) | if type == "array" then .[0] else . end'

valid_command() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }

# The desk: the roster's one seat in the desk group. Its command is the Wheelhouse's name.
desk=$(jq -r '[.seats[] | select(.group == "desk")][0].command // empty' "$roster")
[ -n "$desk" ] || die 1 "the roster has no seat in the desk group"

# A seat is in the roster, or is on trial: its harness is on the checked-out branch and it
# has no roster entry until the trial ends. wake.sh, inbox.sh and the doctor agree.
is_seat() {
  jq -e --arg c "$1" '.seats | any(.command == $c)' "$roster" >/dev/null && return 0
  valid_command "$1" && [ -f "harnesses/$1/AGENTS.md" ]
}
check_from() {
  [ -n "$from" ] || die 1 "say which seat is acting: --from <seat>, or set BEADS_ACTOR"
  is_seat "$from" || die 1 "$from is not a seat in the roster, and there is no harnesses/$from/AGENTS.md here (a seat on trial has one on its branch)"
}

# A seat's session address: <wheelhouse>-<command>, the desk just <wheelhouse>.
session_of() { if [ "$1" = "$desk" ]; then echo "$desk"; else echo "$desk-$1"; fi; }

# Reads a bead as one JSON object, or refuses.
read_bead() {
  local out bead
  out=$(bdb show "$1" --json 2>/dev/null) || die 1 "no bead $1"
  bead=$(jq -c "$first" <<<"$out" 2>/dev/null)
  [ -n "$bead" ] && [ "$bead" != null ] || die 1 "no bead $1"
  printf '%s\n' "$bead"
}

case "$cmd" in
  open)
    [ -n "$title" ] || die 1 "open needs --title"
    case "$kind" in
      question | request | report) ;;
      *) die 1 "open needs --kind question, request or report (a return is made with ask.sh return)" ;;
    esac
    check_from
    priority="${priority#[Pp]}"
    case "$priority" in "" | 0 | 1 | 2 | 3 | 4) ;; *) die 1 "--priority must be 0 to 4 (0 highest)" ;; esac
    if [ "$to" = desk ]; then to="$desk"; fi
    if [ -z "$to" ]; then
      [ "$kind" = report ] || die 1 "a $kind needs --to: the seat that answers it (or desk, when you don't know who should)"
      to="$desk"
    fi
    valid_command "$to" || die 1 "$to is not a seat's command: use a seat's command in lowercase, or desk"
    jq -e --arg c "$to" '.humans // [] | any(.command == $c)' "$roster" >/dev/null &&
      die 1 "$to is a human, not a seat: ask a human with inbox.sh assign"
    is_seat "$to" || die 1 "$to is not a seat in the roster, and there is no harnesses/$to/AGENTS.md here"
    [ "$to" != "$from" ] || die 1 "an ask to yourself is no ask: address the seat that answers it"
    if [ "$kind" = report ]; then
      [ "$to" = "$desk" ] || die 1 "a report goes to the desk ($desk), not to $to"
      [ -z "$blocks" ] || die 1 "a report blocks nothing: leave out --blocks"
    fi
    repo="${repo#repo:}"
    if [ -n "$repo" ] && ! [[ "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
      die 1 "$repo is not a repository name: one name, of letters, digits, '.', '_' and '-'"
    fi
    if [ -n "$blocks" ]; then
      bead=$(read_bead "$blocks") || exit $?
      [ -n "$repo" ] || repo=$(jq -r '[(.labels // [])[] | select(startswith("repo:"))][0] // "" | ltrimstr("repo:")' <<<"$bead")
    fi
    # --title, never positional, so a title starting with "-" is not a flag. One name per
    # --labels: bd reads commas as more labels.
    args=(create --title "$title" --actor "$from" --assignee "$to" --labels ask --labels "ask:$kind")
    [ -n "$repo" ] && args+=(--labels "repo:$repo")
    [ -n "$description" ] && args+=(--description "$description")
    [ -n "$priority" ] && args+=(--priority "$priority")
    [ -n "$blocks" ] && args+=(--deps "blocks:$blocks")
    out=$(bdb "${args[@]}" --json 2>&1) || die 3 "bd create failed: $out"
    newid=$(jq -r "$first | .id // empty" <<<"$out" 2>/dev/null)
    [ -n "$newid" ] || die 3 "bd create printed no id: $out"
    addr=$(session_of "$to")
    jq -n --arg id "$newid" --arg to "$to" --arg from "$from" --arg kind "$kind" --arg blocks "$blocks" --arg repo "$repo" --arg session "$addr" \
      '{id: $id, to: $to, askedBy: $from, kind: $kind,
        blocks: (if $blocks == "" then null else $blocks end),
        repo: (if $repo == "" then null else $repo end),
        session: $session,
        nudge: "If the vendor can message a live session (Claude: SendMessage), send \($session) one line saying ask \($id) is waiting; if no session is live or the send fails, comment that on the ask. Where it can'"'"'t, the check-in rule (ask.sh show at each natural break) is how \($to) finds it."}'
    ;;

  answer)
    [ -n "$id" ] || die 1 "answer needs the ask: ask.sh answer <ask> --text <answer>"
    [ -n "$text" ] || die 1 "answer needs --text: the answer, as the comment on the ask"
    check_from
    bead=$(read_bead "$id") || exit $?
    jq -e '(.labels // []) | index("ask")' <<<"$bead" >/dev/null || die 1 "$id is not an ask (no ask label)"
    akind=$(jq -r '[(.labels // [])[] | select(startswith("ask:")) | ltrimstr("ask:")][0] // ""' <<<"$bead")
    case "$akind" in
      question | request) ;;
      return) die 1 "$id is a returned bead: the desk re-routes it, nothing is answered" ;;
      report) die 1 "$id is a report: it needs no answer, and the desk closes it once read" ;;
      *) die 1 "$id has no ask kind (ask:question or ask:request)" ;;
    esac
    [ "$(jq -r '.status // ""' <<<"$bead")" != closed ] || die 1 "$id is already closed"
    holder=$(jq -r '.assignee // ""' <<<"$bead")
    [ "$holder" = "$from" ] || die 1 "$id is assigned to ${holder:-no one}, not to $from: only the seat an ask is assigned to answers it"
    asker=$(jq -r '.created_by // ""' <<<"$bead")
    [ -n "$asker" ] || die 1 "$id records no asker (created_by), so there is no one to hand the answer back to"
    [ "$asker" != "$from" ] || die 1 "$id was asked by $from itself: there is no one to hand the answer to"
    res=$(bdb comments add "$id" "$text" --actor "$from" 2>&1) || die 3 "bd comments add failed: $res"
    res=$(bdb update "$id" --assignee "$asker" --actor "$from" --if-assignee "$from" 2>&1) || die 3 "bd update failed (the answer is commented, the ask is not yet re-assigned): $res"
    jq -n --arg id "$id" --arg from "$from" --arg to "$asker" '{id: $id, answeredBy: $from, to: $to}'
    ;;

  return)
    [ -n "$id" ] || die 1 "return needs the bead: ask.sh return <bead> --reason <text>"
    [ -n "$reason" ] || die 1 "return needs --reason: why the bead is going back"
    check_from
    [ "$from" != "$desk" ] || die 1 "$from is the desk: it has no one to return a bead to"
    bead=$(read_bead "$id") || exit $?
    [ "$(jq -r '.status // ""' <<<"$bead")" != closed ] || die 1 "$id is already closed"
    jq -e '(.labels // []) | index("ask:report")' <<<"$bead" >/dev/null && die 1 "$id is a report: it is closed by the desk, not returned"
    holder=$(jq -r '.assignee // ""' <<<"$bead")
    [ "$holder" = "$from" ] || die 1 "$id is assigned to ${holder:-no one}, not to $from: only the seat that holds a bead returns it"
    res=$(bdb comments add "$id" "Returned to the desk by $from: $reason" --actor "$from" 2>&1) || die 3 "bd comments add failed: $res"
    # A returned bead carries ask:return and no other kind, so the desk sees a return to route, not
    # a request addressed to it that it could "answer" back to the original asker.
    uargs=(update "$id" --status open --assignee "$desk" --add-label ask --add-label ask:return --actor "$from" --if-assignee "$from")
    while IFS= read -r old; do
      [ -n "$old" ] && uargs+=(--remove-label "$old")
    done < <(jq -r '(.labels // [])[] | select(startswith("ask:") and . != "ask:return")' <<<"$bead")
    res=$(bdb "${uargs[@]}" 2>&1) ||
      die 3 "bd update failed (the reason is commented, the bead is not yet re-assigned): $res"
    jq -n --arg id "$id" --arg from "$from" --arg to "$desk" '{id: $id, returnedBy: $from, to: $to}'
    ;;

  show)
    secs=""
    if [ -n "$older" ]; then
      [[ "$older" =~ ^([0-9]+)([smhd])$ ]] || die 1 "--older-than is a number and s, m, h or d: 30m, 24h, 2d"
      n="${BASH_REMATCH[1]}"
      case "${BASH_REMATCH[2]}" in s) secs=$n ;; m) secs=$((n * 60)) ;; h) secs=$((n * 3600)) ;; d) secs=$((n * 86400)) ;; esac
    fi
    if [ "$all" = 1 ]; then
      [ -z "$seat" ] || die 1 "--all and --seat say opposite things: use one"
    else
      [ -n "$seat" ] || seat="$from"
      [ -n "$seat" ] || die 1 "say whose asks to show: --seat <command>, --all, or set BEADS_ACTOR"
      valid_command "$seat" || die 1 "$seat is not a seat's command"
    fi
    errors='[]'
    failed() { errors=$(jq -c --arg e "$1" 'if index($e) then . else . + [$e] end' <<<"$errors"); }
    largs=(list --label ask --status "open,in_progress,blocked" --limit 0 --json)
    [ "$all" = 1 ] || largs+=(--assignee "$seat")
    # Once bd has failed or timed out, bd is not called again: a hung database would otherwise cost
    # one wait per call, and the desk's wake and the patrol both run show --all. bdfail marks it.
    errf=$(mktemp "${TMPDIR:-/tmp}/ask.XXXXXX" 2>/dev/null) || errf=/dev/null
    trap '[ "$errf" = /dev/null ] || rm -f "$errf"' EXIT
    bdfail=0
    # why <what> <rc>: the first line bd said, or that it ran out of time.
    why() {
      if [ "$2" = 142 ]; then echo "$1 timed out after ${bd_secs}s"
      else
        local m; m=$(head -1 "$errf" 2>/dev/null)
        echo "$1 failed: ${m:-no readable output}"
      fi
    }
    asks='[]'
    out=$(bdb "${largs[@]}" 2>"$errf"); rc=$?
    if [ "$rc" != 0 ]; then
      failed "$(why "bd list" "$rc")"; bdfail=1
    elif asks=$(jq -c '(.data? // .) | if type == "array" then . else error("not a list") end' <<<"$out" 2>/dev/null) && [ -n "$asks" ]; then :; else
      failed "bd list printed nothing readable"; bdfail=1; asks='[]'
    fi
    now="${ASK_NOW:-$(date +%s)}"
    case "$now" in '' | *[!0-9]*) now=$(date +%s) ;; esac
    rows=$(jq -c --argjson now "$now" '
      def age: (.created_at // "") as $c
        | (try ($c | sub("\\.[0-9]+"; "") | sub("[+-]00:?00$"; "Z") | fromdateiso8601) catch null) as $t
        | if $t == null then null else ($now - $t) end;
      def human: if . == null then null elif . < 3600 then "\(. / 60 | floor)m" elif . < 172800 then "\(. / 3600 | floor)h" else "\(. / 86400 | floor)d" end;
      map(select((.status // "") != "closed")
        | (age) as $a
        | ([(.labels // [])[] | select(startswith("ask:")) | ltrimstr("ask:")]) as $ks
        | (if ($ks | index("return")) then "return" else ($ks[0] // null) end) as $k
        | {id, title, kind: $k, askedBy: (.created_by // null), assignee: (.assignee // null),
           answered: (($k == "question" or $k == "request") and (.assignee // "") == (.created_by // "-")),
           createdAt: (.created_at // null), ageSeconds: $a, age: ($a | human), priority: (.priority // null)})
      | sort_by(-(.ageSeconds // -1))' <<<"$asks" 2>/dev/null) || { failed "could not read the asks bd listed"; rows='[]'; }
    if [ -n "$secs" ]; then
      rows=$(jq -c --argjson s "$secs" 'map(select(.ageSeconds != null and .ageSeconds >= $s))' <<<"$rows")
    fi
    # What each ask blocks: the beads that depend on it.
    withblocks='[]'
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      aid=$(jq -r .id <<<"$row")
      bl=null
      if [ "$bdfail" = 0 ]; then
        out=$(bdb dep list "$aid" --direction up --json 2>"$errf"); rc=$?
        if [ "$rc" != 0 ]; then
          failed "$(why "bd dep list $aid" "$rc")"; bdfail=1
        elif bl=$(jq -c '(.data? // .) | map(select((.dependency_type // "blocks") == "blocks") | .id)' <<<"$out" 2>/dev/null) && [ -n "$bl" ]; then :; else
          failed "bd dep list $aid printed nothing readable"; bdfail=1; bl=null
        fi
      fi
      withblocks=$(jq -c --argjson r "$row" --argjson b "$bl" '. + [$r + {blocks: $b}]' <<<"$withblocks")
    done < <(jq -c '.[]' <<<"$rows")
    jq -n --arg seat "$seat" --argjson all "$all" --arg secs "$secs" --argjson asks "$withblocks" --argjson errors "$errors" \
      '{seat: (if $all == 1 then null else $seat end), all: ($all == 1),
        olderThanSeconds: (if $secs == "" then null else ($secs | tonumber) end),
        count: ($asks | length), asks: $asks, errors: $errors}'
    if [ "$errors" != '[]' ]; then
      jq -r '.[]' <<<"$errors" >&2
      exit 3
    fi
    ;;
esac
