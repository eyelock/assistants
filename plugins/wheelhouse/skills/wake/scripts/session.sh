#!/usr/bin/env bash
# One live session per seat: a session bead per seat, labelled session:<command>, held by that seat from
# its wake until its handoff releases it (assistants #179; design ynw-zr1y, decisions 9 to 13).
#
#   session.sh take    --seat <command> [--dir <wheelhouse>] [--force]
#   session.sh release --seat <command> [--dir <wheelhouse>]
#
# The hold is the bead's claim (status in_progress, assignee the seat), not bd's lease expiry: nothing here
# uses bd's --claim, so no lease lapses and nothing reclaims it. A crashed session therefore stays held
# until a start is forced. The bead's notes say who holds it: {token, label, started}.
#
# take prints one JSON object on stdout and exits 0 whatever the state:
#   {state: held, bead}                          the seat took the hold (a new bead is made on first use)
#   {state: refused, bead, holder: {label, started}}   another session holds it: the wake must stop
#   {state: forced, bead, replaced: {label, started}}  --force took it over and commented which it replaced
#   {state: unknown, why}                        bd could not be read or written; the wake carries on
# release prints {state: released|not-held|not-yours|unknown, bead}. A session releases only the hold
# it took: the token is a short hash of the vendor's session id (CLAUDE_CODE_SESSION_ID, which Claude
# Code sets), so a refused second session, whose session-end hook also runs release, leaves the live
# session's hold alone. A vendor that gives no session id (Codex, Copilot, OpenCode, Cursor today) has no
# token, so each refused take adds one line to a count for the seat (in TMPDIR) and each tokenless release
# spends one line and releases nothing; a release that finds the count empty releases the hold. So with the
# live session and N refused ones, the first N ends release nothing and only the last frees the hold, and
# no number of refused sessions can free a live one's hold. Chosen over releasing whatever the seat holds,
# and over one flag, which the second refused session's end would find spent. If the live session ends
# among the first N, the hold stays until forced (the safe side).
#
# Only a human, answering the refused seat's question, or the desk, after checking that the seat's
# named session (<wheelhouse>-<command>) is absent from ListAgents, may pass --force. A seat never forces
# on its own. Every bd call is bounded by WAKE_BD_SECS (default 20).
# Exit codes: 0 done (see state), 1 bad args, 2 not a Wheelhouse, 3 a tool it needs is missing.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: session.sh take --seat <command> [--dir <wheelhouse repo>] [--force]
       session.sh release --seat <command> [--dir <wheelhouse repo>]

take claims the seat's session bead, or reports who holds it; release lets go of it.
--force (take only) takes over a hold: for a human, or the desk after checking, never the seat itself.
EOF
}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/wheelhouse-lib.sh" "$here/../../work-graph/scripts/wheelhouse-lib.sh"; do
  # shellcheck source=../../work-graph/scripts/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found beside $0 or in the work-graph skill's scripts folder" >&2; exit 3; }

cmd="${1:-}"
case "$cmd" in take | release) shift ;; --help | -h) usage; exit 0 ;; *) usage >&2; exit 1 ;; esac
seat=""
dir="."
force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --seat) [ $# -ge 2 ] || { usage >&2; exit 1; }; seat="$2"; shift 2 ;;
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --force) force=1; shift ;;
    --help | -h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done
[ -n "$seat" ] || { echo "no seat: pass --seat <command>" >&2; usage >&2; exit 1; }
[ "$force" = 0 ] || [ "$cmd" = take ] || { echo "--force is for take" >&2; exit 1; }
wl_valid_command "$seat" || { echo "not a seat command: $seat" >&2; exit 1; }
for tool in jq bd; do need "$tool"; done
[ -f "$dir/$WL_ROSTER_REL" ] || { echo "not a Wheelhouse (no $dir/$WL_ROSTER_REL)" >&2; exit 2; }
cd "$dir" || exit 2

bd_secs="${WAKE_BD_SECS:-20}"
label="session:$seat"

# This session: a token (a hash of the vendor's session id, never the id itself, or WAKE_SESSION_TOKEN),
# a label to show a human (no host name or user: the bead is shared), and the time it started.
token="${WAKE_SESSION_TOKEN:-}"
if [ -z "$token" ] && [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
  token=$(printf '%s' "$CLAUDE_CODE_SESSION_ID" | shasum -a 256 2>/dev/null | cut -c1-8)
fi
# With no token, each refused take adds a line to this count, and each release spends one line.
marker="${TMPDIR:-/tmp}/wheelhouse-session-refused.$(printf '%s' "$PWD" | shasum -a 256 2>/dev/null | cut -c1-8).$seat"
mylabel="${WAKE_SESSION_LABEL:-${seat} session ${token:-(pid $PPID)}}"
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mynotes=$(jq -nc --arg t "$token" --arg l "$mylabel" --arg s "$now" '{token: $t, label: $l, started: $s}')

unknown() { jq -nc --arg why "$1" '{state: "unknown", why: $why}'; exit 0; }

# The seat's session bead: its id, status, assignee and notes, or nothing when it has none yet.
bead=""
find_bead() {
  local out
  out=$(limited "$bd_secs" bd list --label "$label" --all --json 2>/dev/null) || return 1
  out=$(bd_data <<<"$out" 2>/dev/null) || return 1
  bead=$(jq -c '[.[]?] | sort_by(.created_at) | .[0] // {}' <<<"$out" 2>/dev/null) || return 1
}
find_bead || unknown "bd could not be read (busy or failing)"
id=$(jq -r '.id // empty' <<<"$bead")
status=$(jq -r '.status // empty' <<<"$bead")
holder=$(jq -c '(.notes // "") | (try fromjson catch {label: "an earlier session", started: null}) | {label: (.label // "an earlier session"), started: (.started // null), token: (.token // "")}' <<<"$bead" 2>/dev/null || echo '{"label":"an earlier session","started":null,"token":""}')

if [ "$cmd" = release ]; then
  rel() { jq -nc --arg s "$1" --arg b "$id" '{state: $s, bead: $b}'; exit 0; }
  if [ -z "$token" ] && [ -s "$marker" ]; then
    rest=$(tail -n +2 "$marker"); if [ -n "$rest" ]; then printf '%s\n' "$rest" >"$marker"; else rm -f "$marker"; fi
    rel not-yours
  fi
  [ -n "$id" ] || rel not-held
  [ "$status" = in_progress ] || rel not-held
  holdtoken=$(jq -r .token <<<"$holder")
  # A session that has a token lets go only of the hold it took; a hold with no token is anyone's.
  if [ -n "$token" ] && [ -n "$holdtoken" ] && [ "$token" != "$holdtoken" ]; then rel not-yours; fi
  if limited "$bd_secs" bd update "$id" --status open --assignee "" --notes "" --if-assignee "$seat" --actor "$seat" >/dev/null 2>&1; then rel released; fi
  rel unknown
fi

# take
if [ -z "$id" ]; then
  new=$(limited "$bd_secs" bd create "Session: $seat" --labels "$label" --type task --priority 4 \
    --description "The live session of $seat. Held (in progress, assigned to $seat) from its wake to its handoff, so a second start finds it and stops. Not work: nothing here is ever picked up, closed or reclaimed. wake.sh --force takes it over (see the wake skill)." \
    --silent --actor "$seat" 2>/dev/null) || unknown "bd could not create the session bead"
  id=$(printf '%s' "$new" | tail -n1)
  [[ "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || unknown "bd did not return a bead id for the session bead"
  status=open
fi
held() { jq -nc --arg b "$id" '{state: "held", bead: $b}'; exit 0; }
refused() { [ -n "$token" ] || echo refused >>"$marker" 2>/dev/null; jq -nc --arg b "$id" --argjson h "$holder" '{state: "refused", bead: $b, holder: {label: $h.label, started: $h.started}}'; exit 0; }

if [ "$status" = in_progress ]; then
  [ "$force" = 1 ] || refused
  # A forced start: reassign the bead over the old hold and say which session it replaced.
  limited "$bd_secs" bd update "$id" --assignee "$seat" --notes "$mynotes" --force --actor "$seat" >/dev/null 2>&1 || unknown "bd would not let the hold be taken over"
  old=$(jq -r '"\(.label)" + (if .started then ", started \(.started)" else "" end)' <<<"$holder")
  limited "$bd_secs" bd comments add "$id" "Forced start at $now: $mylabel took over this hold from $old." --actor "$seat" >/dev/null 2>&1 || true
  jq -nc --arg b "$id" --argjson h "$holder" '{state: "forced", bead: $b, replaced: {label: $h.label, started: $h.started}}'
  exit 0
fi

# Free (open): take it in one step that fails if another session took it first.
if limited "$bd_secs" bd update "$id" --status in_progress --assignee "$seat" --notes "$mynotes" --if-status "$status" --actor "$seat" >/dev/null 2>&1; then
  held
fi
# It changed under us: read it again, and refuse if a session holds it now.
find_bead || unknown "bd could not be read (busy or failing)"
if [ "$(jq -r '.status // empty' <<<"$bead")" = in_progress ]; then
  holder=$(jq -c '(.notes // "") | (try fromjson catch {label: "an earlier session", started: null}) | {label: (.label // "an earlier session"), started: (.started // null), token: (.token // "")}' <<<"$bead" 2>/dev/null)
  refused
fi
unknown "bd would not let the session bead be claimed"
