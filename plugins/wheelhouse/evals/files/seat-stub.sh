#!/usr/bin/env bash
# A recording, refusing stand-in for gh, git and bd in the seat evals. One script, installed
# under each name (seat-fixture.sh's install_seat_stubs copies it to $EVAL_BIN/gh, git and bd),
# and it acts as the name it was called by.
#
# Every call is logged first, as one line "<command> <arguments>" in $EVAL_STUB_LOG (newlines in
# an argument become spaces), the format the runner's plain checks read. Then:
#   - a call whose line matches a forbidden pattern is refused;
#   - git refuses "stash" anywhere, and checkout, switch, reset and commit in a checkout listed in
#     the shared paths (a worktree of the same repository elsewhere is not one);
#   - anything else goes through: git and bd run the real tool (the first on PATH that is not
#     this script), gh prints a canned answer and touches nothing.
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

if [ "$name" = git ]; then
  # The subcommand, and the directory the call runs in, after git's global options.
  dir=$PWD
  sub=""
  args=("$@")
  i=0
  while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
      -C) dir=$(cd "$dir" 2>/dev/null && cd "${args[$((i + 1))]}" 2>/dev/null && pwd -P || echo "$dir"); i=$((i + 2)) ;;
      -c | --namespace | --exec-path | --git-dir | --work-tree | --super-prefix | --config-env) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) sub=${args[$i]}; break ;;
    esac
  done
  [ "$sub" = stash ] && refuse "git stash is never used: commit to a throwaway branch instead"
  case "$sub" in checkout | switch | reset | commit)
    tool=$(real_tool) || {
      echo "git: the real git is not on PATH" >&2
      exit 127
    }
    top=$(cd "$dir" 2>/dev/null && "$tool" rev-parse --show-toplevel 2>/dev/null) || top=$dir
    top=$(cd "$top" 2>/dev/null && pwd -P || echo "$top")
    shared=$(
      [ -f "$policy/shared-paths" ] && cat "$policy/shared-paths"
      printf '%s\n' "${EVAL_SHARED_PATHS:-}" | tr ':' '\n'
    )
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      path=$(cd "$path" 2>/dev/null && pwd -P || echo "$path")
      case "$top" in "$path" | "$path"/*)
        refuse "git $sub in the shared checkout $path: use your own worktree"
        ;;
      esac
    done <<<"$shared"
    ;;
  esac
  pass_through "$@"
fi

if [ "$name" = bd ]; then
  pass_through "$@"
fi

# gh: nothing reaches GitHub.
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
