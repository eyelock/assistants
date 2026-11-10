#!/usr/bin/env bash
# Prints the name a seat's session is launched under, from the roster. Read-only.
#
# A seat's session is named <wheelhouse>-<command>, and the desk's is named just <wheelhouse>
# (hq, hq-okafor, hq-gore): the name is how another session finds it. The Wheelhouse's name is
# the desk's command, the roster's seat in the group desk.
#
# Usage: session-name.sh --seat <command> [--dir <wheelhouse repo>] [--format value|flag]
#   value (default)  the name, such as hq-okafor
#   flag             the launcher flag, --name=hq-okafor (always with "=": ynh reads the word
#                    after a bare -n or --name as the prompt)
# Exit codes: 0 resolved, 1 bad args, 2 no roster, 3 jq missing, 4 the seat is unknown or the
# roster has no desk.
set -uo pipefail

usage() {
  echo "Usage: session-name.sh --seat <command> [--dir <wheelhouse repo>] [--format value|flag]"
}

dir="."
seat=""
format="value"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --seat) [ $# -ge 2 ] || { usage >&2; exit 1; }; seat="$2"; shift 2 ;;
    --format) [ $# -ge 2 ] || { usage >&2; exit 1; }; format="$2"; shift 2 ;;
    --help | -h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done
[ -n "$seat" ] || { usage >&2; exit 1; }
case "$format" in value | flag) ;; *) usage >&2; exit 1 ;; esac
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 3; }
roster="$dir/skills/roster/assets/roster.json"
[ -f "$roster" ] || { echo "no roster at $roster" >&2; exit 2; }

name=$(jq -r --arg seat "$seat" '
  (first(.seats[] | select(.group == "desk") | .command) // empty) as $desk
  | (first(.seats[] | select(.command == $seat)) // empty) as $s
  | if $desk == null or $s == null then empty
    elif $s.group == "desk" then $desk
    else "\($desk)-\($s.command)" end
' "$roster" 2>/dev/null)
if [ -z "$name" ]; then
  echo "no session name for seat '$seat': it is not in the roster, or the roster has no seat in the group desk" >&2
  exit 4
fi
case "$format" in
  value) echo "$name" ;;
  flag) echo "--name=$name" ;;
esac
