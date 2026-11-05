#!/usr/bin/env bash
# The GitHub adapter for open-pr.sh: the one place that knows GitHub's closing keywords and that
# a pull request's release is its milestone. The item is an issue URL.
#   tracker-github.sh closing <issue-url> <last|more> <pr-owner/repo>
#   tracker-github.sh pr-flags <milestone>
set -uo pipefail
case "${1:-}" in
  closing)
    [ $# -eq 4 ] || { echo "usage: tracker-github.sh closing <issue-url> <last|more> <pr-repo>" >&2; exit 1; }
    re='^https://github\.com/([^/]+/[^/]+)/issues/([0-9]+)$'
    [[ "$2" =~ $re ]] || { echo "not a GitHub issue URL: $2" >&2; exit 1; }
    issue_repo=${BASH_REMATCH[1]}; n=${BASH_REMATCH[2]}
    # Same repository: #N. Another: owner/repo#N, which GitHub links and closes across repositories.
    if [ "$issue_repo" = "$4" ]; then target="#$n"; else target="$issue_repo#$n"; fi
    if [ "$3" = last ]; then echo "Closes $target"; else echo "Part of $target"; fi ;;
  pr-flags)
    [ $# -eq 2 ] || { echo "usage: tracker-github.sh pr-flags <milestone>" >&2; exit 1; }
    printf '%s\n%s\n' --milestone "$2" ;;
  *) echo "usage: tracker-github.sh closing|pr-flags ..." >&2; exit 1 ;;
esac
