#!/usr/bin/env bash
# A recording, refusing stand-in for gh, git and bd in the seat evals. One script, installed
# under each name (seat-fixture.sh's install_seat_stubs copies it to $EVAL_BIN/gh, git and bd),
# and it acts as the name it was called by.
#
# Every call is logged first, as one line "<command> <arguments>" in $EVAL_STUB_LOG (newlines in
# an argument become spaces), the format the runner's plain checks read. Then:
#   - a call whose line matches a forbidden pattern is refused;
#   - git refuses "stash" anywhere, and checkout, switch, reset, commit, merge, pull and rebase in a
#     checkout listed in the shared paths (a worktree of the same repository elsewhere is not one).
#     The checkout is the one named by -C, --work-tree and --git-dir (both "=" and space forms) and
#     GIT_WORK_TREE and GIT_DIR, else the directory the call runs in;
#   - anything else goes through: git and bd run the real tool (the first on PATH that is not
#     this script), gh prints a canned answer and touches nothing.
# A gh call that posts a body (--body or -b, --body-file or -F, or a body= field) also logs the body
# as a second line, "gh-body <text>" (newlines become spaces, a file or "-" for stdin is read), so a
# case can check what was posted, such as the byline a review must start with.
# A refused call prints the reason on stderr, exits 1, and is noted in "$EVAL_STUB_LOG.refused"
# (the reason after "::"). It is still in the main log, so a forbidden pattern fails the case.
#
# Policy, next to the log in $EVAL_STUB_LOG's directory (or the environment):
#   forbid         one extended regular expression per line, matched against a call's log line
#                  ($EVAL_FORBID adds more, newline-separated). Write them as the case's
#                  "forbidden" patterns, which match the same line: "^gh pr merge".
#   shared-paths   one directory per line; $EVAL_SHARED_PATHS adds more, colon-separated.
#   gh/<a>-<b>.out gh's answer for "gh <a> <b>" (the first two words that are not flags), else
#                  gh/<a>.out, else a one-line note that gh is stubbed.
# Exit codes: 0 success, 1 a refused call, 2 usage, 127 the real tool was not found.
set -uo pipefail

name=$(basename "$0")
case "$name" in gh | git | bd) ;; *)
  echo "seat-stub: install me as gh, git or bd, not $name" >&2
  exit 2
  ;;
esac
log="${EVAL_STUB_LOG:?EVAL_STUB_LOG is not set}"
policy=$(dirname "$log")
self=$(cd "$(dirname "$0")" && pwd -P)

line="$name"
for a in "$@"; do line="$line $a"; done
line=${line//$'\n'/ }
printf '%s\n' "$line" >>"$log"

refuse() {
  printf '%s :: %s\n' "$line" "$1" >>"$log.refused"
  echo "$name: refused by the eval stub: $1" >&2
  exit 1
}

# The first real tool of this name on PATH: PATH without this script's directory.
real_tool() {
  local dir rest=""
  local IFS=:
  for dir in $PATH; do
    [ -n "$dir" ] && [ "$(cd "$dir" 2>/dev/null && pwd -P)" = "$self" ] && continue
    rest="$rest${rest:+:}$dir"
  done
  PATH=$rest command -v "$name"
}

pass_through() {
  local tool
  tool=$(real_tool) || {
    echo "$name: the real $name is not on PATH" >&2
    exit 127
  }
  exec "$tool" "$@"
}

# Forbidden patterns, from the file and the environment.
patterns=$(
  [ -f "$policy/forbid" ] && cat "$policy/forbid"
  printf '%s\n' "${EVAL_FORBID:-}"
)
while IFS= read -r pattern; do
  [ -n "$pattern" ] || continue
  if printf '%s\n' "$line" | grep -Eq -- "$pattern"; then
    refuse "forbidden by the case: /$pattern/"
  fi
done <<<"$patterns"

# A directory as an absolute path with symbolic links resolved: $2 relative to $1 when it is not
# absolute, left as it is when it does not exist.
canon() {
  local path=$2
  case "$path" in /*) ;; *) path=$1/$path ;; esac
  (cd "$path" 2>/dev/null && pwd -P) || printf '%s\n' "$path"
}

# The shared path that contains $1, if any.
shared_hit() {
  local path shared
  shared=$(
    [ -f "$policy/shared-paths" ] && cat "$policy/shared-paths"
    printf '%s\n' "${EVAL_SHARED_PATHS:-}" | tr ':' '\n'
  )
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    path=$(canon "$PWD" "$path")
    case "$1" in "$path" | "$path"/*)
      printf '%s\n' "$path"
      return 0
      ;;
    esac
  done <<<"$shared"
  return 1
}

if [ "$name" = git ]; then
  # The subcommand, and where the call runs, after git's global options: the directory (-C), the
  # git directory (--git-dir, GIT_DIR) and the work tree (--work-tree, GIT_WORK_TREE), the last
  # two given as "--opt=X" or "--opt X". An option beats the environment, as in git.
  dir=$PWD
  gitdir=${GIT_DIR:-}
  worktree=${GIT_WORK_TREE:-}
  sub=""
  args=("$@")
  i=0
  while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
      -C) dir=$(canon "$dir" "${args[$((i + 1))]:-.}"); i=$((i + 2)) ;;
      --git-dir=*) gitdir=${args[$i]#--git-dir=}; i=$((i + 1)) ;;
      --git-dir) gitdir=${args[$((i + 1))]:-}; i=$((i + 2)) ;;
      --work-tree=*) worktree=${args[$i]#--work-tree=}; i=$((i + 1)) ;;
      --work-tree) worktree=${args[$((i + 1))]:-}; i=$((i + 2)) ;;
      -c | --namespace | --exec-path | --super-prefix | --config-env) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) sub=${args[$i]}; break ;;
    esac
  done
  [ "$sub" = stash ] && refuse "git stash is never used: commit to a throwaway branch instead"
  case "$sub" in checkout | switch | reset | commit | merge | pull | rebase)
    tool=$(real_tool) || {
      echo "git: the real git is not on PATH" >&2
      exit 127
    }
    # Every checkout the call can change: the work tree when one is named, else where it runs; and
    # the checkout owning a named git directory (a linked worktree's own directory, under
    # .git/worktrees, is not its owner's checkout).
    candidates=()
    if [ -n "$worktree" ]; then
      candidates+=("$(canon "$dir" "$worktree")")
    else
      top=$(cd "$dir" 2>/dev/null && "$tool" rev-parse --show-toplevel 2>/dev/null) || top=$dir
      candidates+=("$(canon "$dir" "$top")")
    fi
    if [ -n "$gitdir" ]; then
      gitdir=$(canon "$dir" "$gitdir")
      case "$gitdir" in
        */.git/worktrees/*) ;;
        */.git) candidates+=("${gitdir%/.git}") ;;
        *) candidates+=("$gitdir") ;;
      esac
    fi
    for candidate in "${candidates[@]}"; do
      if hit=$(shared_hit "$candidate"); then
        refuse "git $sub in the shared checkout $hit: use your own worktree"
      fi
    done
    ;;
  esac
  pass_through "$@"
fi

if [ "$name" = bd ]; then
  pass_through "$@"
fi

# gh: nothing reaches GitHub. A posted body is logged, as one "gh-body <text>" line.
log_body() {
  local text=$1
  text=${text//$'\n'/ }
  printf 'gh-body %s\n' "$text" >>"$log"
}
body_file() {
  if [ "$1" = "-" ]; then cat; else cat -- "$1" 2>/dev/null; fi
}
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in
    --body | -b) log_body "${args[$((i + 1))]:-}" ;;
    --body=*) log_body "${args[$i]#--body=}" ;;
    --body-file | -F) log_body "$(body_file "${args[$((i + 1))]:-}")" ;;
    --body-file=*) log_body "$(body_file "${args[$i]#--body-file=}")" ;;
    body=*) log_body "${args[$i]#body=}" ;;
  esac
done
words=()
for a in "$@"; do
  case "$a" in -*) ;; *) words+=("$a") ;; esac
  [ ${#words[@]} -ge 2 ] && break
done
for answer in "${words[0]:-}-${words[1]:-}" "${words[0]:-}"; do
  if [ -n "$answer" ] && [ -f "$policy/gh/$answer.out" ]; then
    cat "$policy/gh/$answer.out"
    exit 0
  fi
done
echo "(gh is stubbed in this eval; the call was recorded)"
