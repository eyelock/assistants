#!/usr/bin/env bash
# The fallback adapter for open-pr.sh, for a tracker kind with no adapter of its own (jira, or another):
# it names the item in the PR body and sets no release flag, since a pull request has no release
# field there. Give a kind its own adapter, tracker-<kind>.sh, when its closing link has a form.
#   tracker-generic.sh canon <ref>                   prints the reference unchanged
#   tracker-generic.sh closing <item> <last|more> <pr-repo>
#   tracker-generic.sh pr-flags <release>
set -uo pipefail
case "${1:-}" in
  closing)
    [ $# -eq 4 ] || { echo "usage: tracker-generic.sh closing <item> <last|more> <pr-repo>" >&2; exit 1; }
    if [ "$3" = last ]; then echo "Tracker item (this is the last open bead on it): $2"; else echo "Tracker item (part of it): $2"; fi ;;
  canon) printf '%s\n' "${2:-}" ;;
  pr-flags) ;;
  *) echo "usage: tracker-generic.sh closing|pr-flags|canon ..." >&2; exit 1 ;;
esac
