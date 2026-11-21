#!/usr/bin/env bash
# The session-start guard of a Wheelhouse repository: a plain vendor session, one not started
# through ynh, is told it is not a seat. A session ynh launched is left alone: ynh exports the
# run's labels as YNH_LABELS to the vendor it starts, and every seat's harness carries the label
# wheelhouse:<name>, so a session with that label is a seat and prints nothing.
#
# Usage: bare-guard.sh --vendor claude|codex|cursor
#   claude, codex: the guard is plain text on stdout, which both add to the session's context.
#   cursor: the guard is {"additional_context": "..."}, the field Cursor reads.
# Always exits 0: a guard must never stop a session from starting.
# Exit codes: 0 always (a bad argument prints a usage line on stderr and nothing on stdout).
set -uo pipefail

vendor=""
while [ $# -gt 0 ]; do
  case "$1" in
    --vendor) vendor="${2:-}"; [ $# -ge 2 ] && shift; shift ;;
    *) shift ;;
  esac
done
case "$vendor" in
  claude | codex | cursor) ;;
  *) echo "usage: bare-guard.sh --vendor claude|codex|cursor" >&2; exit 0 ;;
esac

# A seat started through ynh carries wheelhouse:<name> in YNH_LABELS (comma-separated key:value).
case ",${YNH_LABELS:-}," in
  *,wheelhouse:*) exit 0 ;;
esac

# One line, with no quote or backslash, so the Cursor form is valid JSON as it stands.
msg="This is a plain $vendor session in a Wheelhouse repository, not a seat started through ynh. You are not the desk or any seat: do not act as one, do not run wake.sh, do not claim or close beads as a seat, and do not write seat memory (seat/<name>). Help with the request as an ordinary assistant, and read the repository's AGENTS.md for its rules. To work as a seat, start it by its command (ynh run <command> or the launcher ynh installed)."

if [ "$vendor" = cursor ]; then
  printf '{"additional_context": "%s"}\n' "$msg"
else
  printf '%s\n' "$msg"
fi
exit 0
