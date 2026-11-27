#!/usr/bin/env bash
# worktree.sh: where a seat's git worktrees live, decided by the Wheelhouse, never invented by the seat.
#
#   add     make a worktree for a branch at the policy path; print that absolute path and nothing
#           else; append the line "Worktree: <path>" to the bead's notes as the acting seat (list finds the bead
#           by that line, with one bd call).
#   list    every worktree of every repository the Wheelhouse reaches, with seat, repo, branch,
#           bead and path, and whether it is stale (bead closed, or branch merged).
#   remove  remove one worktree: its own seat's, or any seat's whose bead is closed. Never --force,
#           prune, move, lock or repair; refuses a path outside the policy layout and one with
#           uncommitted work.
#
# The policy is worktrees.json in the Wheelhouse root, beside tracker.json:
#   {"layout": "{repo}/.worktrees/{seat}/{branch}"}
# {repo} is the repository name, {seat} the seat command, {branch} the branch (slashes kept), {scratchpad}
# the seat's scratchpad ($WORKTREE_SCRATCHPAD, else ${TMPDIR:-/tmp}/worktrees).
# A relative layout is relative to the folder that holds the repositories' checkouts (the parent of
# the Wheelhouse root), so the layout above is <checkout>/.worktrees/<seat>/<branch>. With no
# worktrees.json the layout is {scratchpad}/{repo}/{branch}. Checkouts are the sibling folders the
# constitution (AGENTS.md) names under "What it reaches" as `../<name>`, or --repo-path name=dir.
#
# Run it from the Wheelhouse root, or pass --dir. Output: the path (add), a JSON list (list), nothing (remove).
# Exit codes: 0 done, 1 bad args or refused, 2 not a Wheelhouse, 3 a tool it needs failed or is missing.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/wheelhouse-lib.sh" "$here/../../work-graph/scripts/wheelhouse-lib.sh"; do
  # shellcheck source=../../work-graph/scripts/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found beside $0 or in the work-graph skill's scripts folder" >&2; exit 3; }
# shellcheck disable=SC2034  # read by the library
WL_PREFIX="worktree.sh: "

usage() {
  cat <<'EOT'
Usage: worktree.sh add --seat <command> --repo <name> --branch <branch> [--bead <id>] [--base <ref>]
       worktree.sh list [--repo <name>] [--stale]
       worktree.sh remove <path> --seat <command>

Common: --dir <Wheelhouse root> (default: the current directory),
        --repo-path <name>=<checkout> (repeatable; else the checkouts AGENTS.md names).

add     --branch must exist, or start with "<seat>/" (then it is created from --base,
        default origin/develop, else origin/main). Prints the absolute path of the worktree.
list    Prints a JSON list of {seat, repo, branch, bead, path, stale, why}. --stale keeps those
        whose bead is closed or whose branch is merged (its upstream gone, or already in the
        default branch of a pushed branch).
remove  --seat is the acting seat: it may remove its own worktrees; the roster's dispatcher, or
        the seats in WORKTREE_CLEANERS (space-separated, replaces it), may remove one whose bead is closed.
EOT
}

dir=. ; declare -a repo_paths=()
cmd=${1:-}; [ $# -gt 0 ] && shift
seat='' repo='' branch='' bead='' base='' want_stale='' target=''
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir=${2:?--dir needs a path}; shift 2 ;;
    --repo-path) repo_paths+=("${2:?--repo-path needs name=dir}"); shift 2 ;;
    --seat) seat=${2:?--seat needs a command}; shift 2 ;;
    --repo) repo=${2:?--repo needs a name}; shift 2 ;;
    --branch) branch=${2:?--branch needs a name}; shift 2 ;;
    --bead) bead=${2:?--bead needs an id}; shift 2 ;;
    --base) base=${2:?--base needs a ref}; shift 2 ;;
    --stale) want_stale=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; die 1 "unknown option $1" ;;
    *) [ -z "$target" ] || die 1 "one path only"; target=$1; shift ;;
  esac
done
case "$cmd" in add|list|remove) ;; -h|--help|help) usage; exit 0 ;; *) usage >&2; exit 1 ;; esac

need jq; need git
dir=$(cd "$dir" 2>/dev/null && pwd) || die 2 "no such directory"
[ -f "$dir/AGENTS.md" ] || die 2 "$dir is not a Wheelhouse (no AGENTS.md)"
parent=$(dirname "$dir")
scratch=${WORKTREE_SCRATCHPAD:-${TMPDIR:-/tmp}/worktrees}; scratch=${scratch%/}

# --- the policy -------------------------------------------------------------------------------
layout='{scratchpad}/{repo}/{branch}'
if [ -f "$dir/worktrees.json" ]; then
  layout=$(jq -er '.layout | select(type == "string" and length > 0)' "$dir/worktrees.json" 2>/dev/null) \
    || die 2 "$dir/worktrees.json needs a non-empty \"layout\" string"
fi

# expand SEAT REPO BRANCH: the layout with its placeholders filled, made absolute.
expand() {
  local p=$layout
  p=${p//\{scratchpad\}/$scratch}; p=${p//\{repo\}/$2}; p=${p//\{seat\}/$1}; p=${p//\{branch\}/$3}
  case "$p" in /*) ;; *) p="$parent/$p" ;; esac
  printf '%s\n' "$p"
}

# layout_regex REPO: an ERE for a worktree path of the layout; group 1 the seat, the last the branch.
layout_regex() {
  local p=$layout out='' rest tok
  p=${p//\{scratchpad\}/$scratch}; p=${p//\{repo\}/$1}
  case "$p" in /*) ;; *) p="$parent/$p" ;; esac
  rest=$p
  while [ -n "$rest" ]; do
    case "$rest" in
      \{seat\}*) out+='([^/]+)'; rest=${rest#\{seat\}} ;;
      \{branch\}*) out+='(.+)'; rest=${rest#\{branch\}} ;;
      *) tok=${rest:0:1}; rest=${rest:1}
         case "$tok" in [][\\.^\$*+?\(\)\{\}\|]) out+="\\$tok" ;; *) out+=$tok ;; esac ;;
    esac
  done
  printf '^%s$\n' "$out"
}

# --- the repositories -------------------------------------------------------------------------
declare -a names=() paths=()
if [ ${#repo_paths[@]} -gt 0 ]; then
  for rp in "${repo_paths[@]}"; do names+=("${rp%%=*}"); paths+=("${rp#*=}"); done
else
  # The sibling checkouts AGENTS.md names under "What it reaches", as `../name` in backticks.
  while IFS= read -r n; do names+=("$n"); paths+=("$parent/$n"); done < <(
    grep -o '`\.\./[A-Za-z0-9_.-]*`' "$dir/AGENTS.md" | tr -d '`' | sed 's|^\.\./||' | awk '!seen[$0]++')
fi
checkout_of() { local i; for i in "${!names[@]}"; do [ "${names[$i]}" = "$1" ] && { printf '%s\n' "${paths[$i]}"; return 0; }; done; return 1; }

valid_seat() { wl_valid_command "$1"; }
valid_branch() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] && [[ "$1" != *..* ]] && [[ "$1" != */ ]] && [[ "$1" != *//* ]]; }

bd_note() { # bead path seat
  [ -n "$1" ] || return 0
  need bd
  limited "${WL_BD_SECS:-20}" bd update "$1" --append-notes "Worktree: $2" --actor "$3" >/dev/null 2>&1 \
    || echo "worktree.sh: could not note the worktree on $1; add 'Worktree: $2' by hand" >&2
}

# bead_of PATH: the bead whose notes hold the exact line "Worktree: PATH", else empty (one bd call).
bead_of() {
  command -v bd >/dev/null 2>&1 || return 0
  limited "${WL_BD_SECS:-20}" bd list --all --limit 0 --notes-contains "Worktree: $1" --json 2>/dev/null | bd_data \
    | jq -r --arg l "Worktree: $1" '[.[]? | select((.notes // "") | split("\n") | index($l)) | .id][0] // empty' 2>/dev/null
  return 0
}

bead_status() { limited "${WL_BD_SECS:-20}" bd show "$1" --json 2>/dev/null | bd_first | jq -r '.status // empty' 2>/dev/null; }

# worktrees_of CHECKOUT: "path<TAB>branch" per linked worktree.
worktrees_of() {
  git -C "$1" worktree list --porcelain 2>/dev/null | awk -v root="$1" '
    /^worktree /{p=substr($0,10); b=""} /^branch /{b=$2; sub("refs/heads/","",b)}
    /^$/{ if (p!="" && p!=root) print p "\t" b; p="" }
    END{ if (p!="" && p!=root) print p "\t" b }'
}

branch_merged() { # checkout branch
  local up def
  up=$(git -C "$1" for-each-ref --format='%(upstream:track)|%(upstream)' "refs/heads/$2" 2>/dev/null)
  # Tracking origin/develop before any push is not a merge.
  case "$up" in '[gone]|'*) return 0 ;; '|'|''|*'|refs/remotes/origin/develop'|*'|refs/remotes/origin/main') return 1 ;; esac
  for def in origin/develop origin/main; do
    git -C "$1" rev-parse -q --verify "$def" >/dev/null 2>&1 || continue
    git -C "$1" merge-base --is-ancestor "refs/heads/$2" "$def" 2>/dev/null && return 0
    return 1
  done
  return 1
}

# --- add --------------------------------------------------------------------------------------
do_add() {
  local co path
  [ -n "$seat" ] && [ -n "$repo" ] && [ -n "$branch" ] || { usage >&2; die 1 "add needs --seat, --repo and --branch"; }
  valid_seat "$seat" || die 1 "'$seat' is not a command name"
  valid_branch "$branch" || die 1 "'$branch' is not a usable branch name"
  co=$(checkout_of "$repo") || die 1 "no checkout known for '$repo' (AGENTS.md names ${names[*]:-none}; or pass --repo-path)"
  git -C "$co" rev-parse --git-dir >/dev/null 2>&1 || die 1 "$co is not a git checkout"
  path=$(expand "$seat" "$repo" "$branch")
  [ ! -e "$path" ] || die 1 "$path already exists"
  if git -C "$co" show-ref --verify -q "refs/heads/$branch"; then
    git -C "$co" worktree add "$path" "$branch" >&2 || die 3 "git worktree add failed"
  else
    case "$branch" in
      "$seat"/*) ;;
      *) die 1 "branch '$branch' does not exist and does not start with '$seat/': a seat creates only its own prefixed branches" ;;
    esac
    if [ -z "$base" ]; then
      for base in origin/develop origin/main; do git -C "$co" rev-parse -q --verify "$base" >/dev/null 2>&1 && break; base=; done
      [ -n "$base" ] || die 1 "no --base given and neither origin/develop nor origin/main exists"
    fi
    git -C "$co" worktree add -b "$branch" "$path" "$base" >&2 || die 3 "git worktree add failed"
  fi
  bd_note "$bead" "$path" "$seat"
  printf '%s\n' "$path"
}

# --- list -------------------------------------------------------------------------------------
do_list() {
  local i n co wt br rx s seatname bead_id why stale out='[]'
  for i in "${!names[@]}"; do
    n=${names[$i]}; co=${paths[$i]}
    { [ -z "$repo" ] || [ "$repo" = "$n" ]; } || continue
    [ -d "$co" ] || continue
    rx=$(layout_regex "$n")
    while IFS=$'\t' read -r wt br; do
      [ -n "$wt" ] || continue
      seatname=; [[ "$wt" =~ $rx ]] && [ "$layout" != "${layout//\{seat\}/}" ] && seatname=${BASH_REMATCH[1]}
      bead_id=$(bead_of "$wt"); why=; stale=false
      if [ -n "$bead_id" ] && [ "$(bead_status "$bead_id")" = closed ]; then stale=true; why="bead $bead_id is closed"; fi
      if [ "$stale" = false ] && [ -n "$br" ] && branch_merged "$co" "$br"; then stale=true; why="branch $br is merged"; fi
      s=$(jq -n --arg seat "$seatname" --arg repo "$n" --arg branch "$br" --arg bead "$bead_id" --arg path "$wt" \
            --argjson stale "$stale" --arg why "$why" \
            '{seat: (if $seat == "" then null else $seat end), repo: $repo, branch: (if $branch == "" then null else $branch end), bead: (if $bead == "" then null else $bead end), path: $path, stale: $stale, why: (if $why == "" then null else $why end)}')
      out=$(jq -c --argjson s "$s" '. + [$s]' <<<"$out")
    done < <(worktrees_of "$co")
  done
  if [ -n "$want_stale" ]; then jq '[.[] | select(.stale)]' <<<"$out"; else jq '.' <<<"$out"; fi
}

# cleaners: seats that may remove another's finished worktree: $WORKTREE_CLEANERS, else the roster's dispatcher.
cleaners() {
  if [ -n "${WORKTREE_CLEANERS:-}" ]; then printf '%s\n' $WORKTREE_CLEANERS; return 0; fi
  jq -r '.seats[]? | select(.role == "dispatcher") | .command' "$dir/$WL_ROSTER_REL" 2>/dev/null || true
}

# --- remove -----------------------------------------------------------------------------------
do_remove() {
  local i n co rx wt br found='' owner='' bead_id st cleaner c
  [ -n "$target" ] && [ -n "$seat" ] || { usage >&2; die 1 "remove needs a path and --seat"; }
  valid_seat "$seat" || die 1 "'$seat' is not a command name"
  case "$target" in /*) ;; *) die 1 "give the worktree's absolute path" ;; esac
  target=${target%/}
  for i in "${!names[@]}"; do
    n=${names[$i]}; co=${paths[$i]}; [ -d "$co" ] || continue
    rx=$(layout_regex "$n")
    [[ "$target" =~ $rx ]] || continue
    while IFS=$'\t' read -r wt br; do
      if [ "$wt" = "$target" ]; then found=$i; owner=${BASH_REMATCH[1]:-}; break; fi
    done < <(worktrees_of "$co")
    [ -n "$found" ] && break
  done
  [ -n "$found" ] || die 1 "$target is not a worktree of the policy layout ($layout) in a repository this Wheelhouse reaches"
  # A layout with no {seat} cannot tell whose a worktree is, so any seat may remove one.
  co=${paths[$found]}
  if [ "$layout" != "${layout//\{seat\}/}" ] && [ "$owner" != "$seat" ]; then
    cleaner=no; for c in $(cleaners); do [ "$c" = "$seat" ] && cleaner=yes; done
    [ "$cleaner" = yes ] || die 1 "$seat may remove only its own worktrees (this one is ${owner:-not told apart by this layout})"
    bead_id=$(bead_of "$target")
    [ -n "$bead_id" ] || die 1 "$target has no bead noting it, so it is not shown to be finished work"
    st=$(bead_status "$bead_id")
    [ "$st" = closed ] || die 1 "bead $bead_id is $st, not closed: only the owner may remove it"
  fi
  if [ -n "$(git -C "$target" status --porcelain --untracked-files=all 2>/dev/null)" ]; then
    die 1 "$target has uncommitted work: commit or discard it yourself first"
  fi
  git -C "$co" worktree remove "$target" >&2 || die 3 "git worktree remove refused"
  echo "removed $target" >&2
}

case "$cmd" in add) do_add ;; list) do_list ;; remove) do_remove ;; esac
