#!/usr/bin/env bash
# Claim a bead as a seat, and say plainly when the bead is outside the seat's charter.
#
#   claim.sh <bead> --seat <command>           claim it (bd update <bead> --claim), then warn
#   claim.sh <bead> --seat <command> --check   warn only, claim nothing (for a hand-off)
#
# A seat's roster entry may list `specialities`, bead labels such as `repo:ynh`; a specialist
# takes only beads carrying one of them. A bead that carries a `repo:` label but none of the
# seat's specialities is outside its charter: the claim still happens, and one line goes to
# stderr, for example:
#
#   warning: ynw-12 is repo:assistants; your charter takes repo:ynh. Say so to the desk, or
#   hand it back (ask.sh return), unless you were given it on purpose.
#
# An in-charter claim prints nothing extra, and neither does a seat with no specialities, a
# seat not in the roster, or a bead with no repo: label. When bd declines the claim, the script
# passes bd's message and exit code through and adds nothing of its own.
# bd's own output goes to stdout unchanged; the claim's exit code is bd's.
#
# Run it from the Wheelhouse repository's root, or pass --dir.
# Exit codes: 0 done, 1 bad args, 2 not a Wheelhouse, 3 a tool it needs (jq, bd) is missing or failed.
# Every bd call is bounded (CLAIM_BD_TIMEOUT seconds, default 20).
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/wheelhouse-lib.sh" "$here/../../work-graph/scripts/wheelhouse-lib.sh"; do
  # shellcheck source=wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found beside $0 or in the work-graph skill's scripts folder" >&2; exit 3; }

usage() {
  cat <<'USAGE'
Usage: claim.sh <bead> --seat <command> [--check] [--dir <wheelhouse repo>]
USAGE
}

dir="."; seat="${BEADS_ACTOR:-}"; id=""; check=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --check) check=1; shift ;;
    --dir | --seat)
      [ $# -ge 2 ] || { usage >&2; exit 1; }
      case "$1" in --dir) dir="$2" ;; --seat) seat="$2" ;; esac
      shift 2 ;;
    -*) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
    *) [ -z "$id" ] || { echo "unknown argument: $1" >&2; usage >&2; exit 1; }; id="$1"; shift ;;
  esac
done
[ -n "$id" ] || { usage >&2; exit 1; }
wl_valid_command "$seat" || { echo "claim.sh needs --seat <command> (lower-case letters, digits, hyphens)" >&2; exit 1; }

need jq
need bd
[ -f "$dir/$WL_ROSTER_REL" ] || die 2 "not a Wheelhouse (no $dir/$WL_ROSTER_REL)"
cd "$dir" || exit 2
roster=$WL_ROSTER_REL

bd_secs="${CLAIM_BD_TIMEOUT:-$WL_BD_SECS}"
case "$bd_secs" in '' | *[!0-9]*) bd_secs=20 ;; esac
bdb() { limited "$bd_secs" bd "$@"; }

if [ "$check" = 0 ]; then
  bdb update "$id" --claim --actor "$seat" --json
  rc=$?
  [ "$rc" = 0 ] || exit "$rc"
fi

# The warning never fails the claim: anything unreadable here is silent.
specs=$(jq -r --arg c "$seat" '[.seats[] | select(.command == $c) | (.specialities // [])[]] | join(", ")' "$roster" 2>/dev/null) || specs=""
[ -n "$specs" ] || exit 0
bead=$(bdb show "$id" --json 2>/dev/null | bd_first 2>/dev/null) || exit 0
repos=$(jq -r --arg c "$seat" --slurpfile r "$roster" '
  ([$r[0].seats[] | select(.command == $c) | (.specialities // [])[]]) as $specs
  | ((.labels // []) | map(select(startswith("repo:")))) as $repos
  | if ($repos | length) > 0 and (((.labels // []) | map(select(. as $l | $specs | index($l)))) | length) == 0
    then $repos | join(", ") else empty end' <<<"$bead" 2>/dev/null) || exit 0
[ -n "$repos" ] || exit 0
echo "warning: $id is $repos; your charter takes $specs. Say so to the desk, or hand it back (ask.sh return), unless you were given it on purpose." >&2
exit 0
