#!/usr/bin/env bash
# The fallback adapter for open-pr.sh, for a tracker kind with no adapter of its own (jira, or another):
# it names the item in the PR body and sets no release flag, since a pull request has no release
# field there. Give a kind its own adapter, tracker-<kind>.sh, when its closing link has a form.
#   tracker-generic.sh canon <ref>                   prints the reference unchanged
#   tracker-generic.sh closing <item> <last|more> <pr-repo>
#   tracker-generic.sh pr-flags <release>
#   tracker-generic.sh release <item>   a fault (exit 3): the generic adapter cannot read a release
#   tracker-generic.sh state <item>     likewise
# A tracker needs its own tracker-<kind>.sh, with release and state written as plain code, before
# open-pr.sh can open a PR for it.
set -uo pipefail
case "${1:-}" in
  closing)
    [ $# -eq 4 ] || { echo "usage: tracker-generic.sh closing <item> <last|more> <pr-repo>" >&2; exit 1; }
    if [ "$3" = last ]; then echo "Tracker item (this is the last open bead on it): $2"; else echo "Tracker item (part of it): $2"; fi ;;
  canon) printf '%s\n' "${2:-}" ;;
  pr-flags) ;;
  release | state)
    echo "tracker-generic.sh cannot read a $1: add tracker-<kind>.sh for this tracker's kind" >&2
    exit 3 ;;
  *) echo "usage: tracker-generic.sh closing|pr-flags|canon|release|state ..." >&2; exit 1 ;;
esac
