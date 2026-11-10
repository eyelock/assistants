#!/usr/bin/env bash
# The GitHub adapter for open-pr.sh: the one place that knows GitHub's closing keywords and that
# a pull request's release is its milestone. The item is an issue URL.
#   tracker-github.sh canon <ref>     prints the canonical item id: owner/repo#N, lower-cased (GitHub
#                                     names are case-insensitive); accepts the URL or owner/repo#N
#   tracker-github.sh closing <issue-url> <last|more> <pr-owner/repo>
#   tracker-github.sh pr-flags <milestone>
#   tracker-github.sh release <issue-url>   prints the issue's milestone, empty when it has none
#   tracker-github.sh state <issue-url>     prints open, closed or unknown
# Nothing here runs text from a config: the commands are written out below, and the item reaches
# gh only as one argument, after it has matched the safe pattern for an issue URL.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/wheelhouse-lib.sh" "$here/../../../lib/wheelhouse-lib.sh"; do
  # shellcheck source=../../../lib/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found beside $0 or in the plugin's lib folder" >&2; exit 3; }


safe_url='^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+$'

need_issue() {
  [[ "${1:-}" =~ $safe_url ]] || { echo "not a GitHub issue URL: ${1:-}" >&2; exit 1; }
}

case "${1:-}" in
  closing)
    [ $# -eq 4 ] || { echo "usage: tracker-github.sh closing <issue-url> <last|more> <pr-repo>" >&2; exit 1; }
    re='^https://github\.com/([^/]+/[^/]+)/issues/([0-9]+)$'
    [[ "$2" =~ $re ]] || { echo "not a GitHub issue URL: $2" >&2; exit 1; }
    issue_repo=${BASH_REMATCH[1]}; n=${BASH_REMATCH[2]}
    # Same repository: #N. Another: owner/repo#N, which GitHub links and closes across repositories.
    if [ "$issue_repo" = "$4" ]; then target="#$n"; else target="$issue_repo#$n"; fi
    if [ "$3" = last ]; then echo "Closes $target"; else echo "Part of $target"; fi ;;
  canon)
    [ $# -eq 2 ] || { echo "usage: tracker-github.sh canon <ref>" >&2; exit 1; }
    re_url='^https://github\.com/([^/]+/[^/]+)/issues/([0-9]+)/?$'
    re_short='^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([0-9]+)$'
    if [[ "$2" =~ $re_url ]] || [[ "$2" =~ $re_short ]]; then
      name=$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
      echo "$name#${BASH_REMATCH[2]}"
    else
      echo "$2"
    fi ;;
  release)
    need_issue "${2:-}"
    limited "$WL_GH_SECS" gh issue view "$2" --json milestone --jq '.milestone.title // empty' || exit 3 ;;
  state)
    need_issue "${2:-}"
    st=$(limited "$WL_GH_SECS" gh issue view "$2" --json state --jq .state) || exit 3
    case "$st" in OPEN) echo open ;; CLOSED) echo closed ;; *) echo unknown ;; esac ;;
  pr-flags)
    [ $# -eq 2 ] || { echo "usage: tracker-github.sh pr-flags <milestone>" >&2; exit 1; }
    printf '%s\n%s\n' --milestone "$2" ;;
  *) echo "usage: tracker-github.sh closing|pr-flags|canon|release|state ..." >&2; exit 1 ;;
esac
