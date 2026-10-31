#!/usr/bin/env bash
# Patrols a Wheelhouse's repositories on GitHub and prints only what changed
# since the last patrol, so a seat on a timer is woken only when there's news.
#
# Each run reads, with gh, every repository's open and recently closed pull
# requests (state, draft, base branch, merge state, CI on the head) and
# issues, and the latest CI on its default branch. It compares them with the
# snapshot the last run left, prints the changes as a JSON list, and saves the
# new snapshot. Nothing changed: it prints [] and exits 0. The first run has
# nothing to compare with: it saves the snapshot and prints [].
#
# The repositories: each --repo <owner/name>, else $WHEELHOUSE_REPOS
# (space-separated owner/name), else the Wheelhouse's own GitHub remote and
# that of every checkout its constitution (AGENTS.md) names under
# "## What it reaches" as a backticked relative path, such as `../api`.
#
# The snapshot: --snapshot <file>, else .wheelhouse/patrol.json in the
# Wheelhouse repository (the folder ignores itself in git). --dry-run compares
# and prints without saving it, so a timer can ask whether there's news and
# leave the patrol itself to the seat it wakes.
#
# A change: {kind, repo, number, title, url, ...}. kind is one of
#   pr-opened, pr-merged (method: merge|squash), pr-closed, pr-reopened,
#   pr-draft, pr-ready, pr-retargeted (from, to), pr-dirty, pr-ci-red,
#   pr-ci-green (red before, green again), issue-opened, issue-closed
#   (reason), issue-reopened, ci-red and ci-green (the default branch's CI;
#   branch instead of number), and error (detail), when gh couldn't read a
#   repository: its last snapshot is kept, so nothing is lost or reported twice.
# A squash merge and a rebase merge both leave one parent: both read as squash.
#
# Exit codes: 0 done, 1 bad args, 2 not a Wheelhouse, 3 a tool (jq, gh, git)
# is missing or gh failed for a repository (the change list says which).
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: patrol.sh [--dir <wheelhouse repo>] [--repo <owner/name>]... [--snapshot <file>]
                 [--limit <n>] [--dry-run]

Prints a JSON list of what changed in the repositories' pull requests, issues
and CI since the last run, and saves a new snapshot. [] means nothing changed.
--limit is how many of the most recent pull requests and issues it reads per
repository (default 30). --dry-run prints the changes without saving the
snapshot.
EOF
}

die() { echo "$2" >&2; exit "$1"; }

dir="."; snapshot=""; limit=30; repos=(); dry=false
while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --dry-run) dry=true; shift ;;
    --dir | --repo | --snapshot | --limit)
      [ $# -ge 2 ] || { usage >&2; exit 1; }
      case "$1" in
        --dir) dir="$2" ;; --repo) repos+=("$2") ;; --snapshot) snapshot="$2" ;; --limit) limit="$2" ;;
      esac
      shift 2 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done
[[ "$limit" =~ ^[1-9][0-9]*$ ]] || die 1 "--limit must be a positive number"

for t in jq gh git; do command -v "$t" >/dev/null 2>&1 || die 3 "$t is required"; done
[ -d "$dir" ] || die 2 "no folder $dir"
cd "$dir" || exit 2
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# owner/name of a checkout's GitHub remote, or nothing.
gh_name() {
  git -C "$1" remote get-url origin 2>/dev/null |
    sed -nE 's#^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/]+)$#\2#p' |
    sed -E 's#\.git$##'
}

if [ ${#repos[@]} -eq 0 ] && [ -n "${WHEELHOUSE_REPOS:-}" ]; then
  read -r -a repos <<<"$WHEELHOUSE_REPOS"
fi
if [ ${#repos[@]} -eq 0 ]; then
  [ -f AGENTS.md ] || die 2 "not a Wheelhouse (no AGENTS.md): pass --repo"
  own=$(gh_name .)
  [ -n "$own" ] && repos+=("$own")
  while IFS= read -r path; do
    name=$(gh_name "$path")
    [ -n "$name" ] && repos+=("$name")
  done < <(awk '/^## /{on = ($0 ~ /^## What it reaches/)} on' AGENTS.md | grep -oE '`\.\.?/[^`]+`' | tr -d '`')
fi
[ ${#repos[@]} -gt 0 ] || die 1 "no repositories: pass --repo <owner/name>, or name their checkouts under What it reaches"
for r in "${repos[@]}"; do
  [[ "$r" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die 1 "$r is not owner/name"
done

if [ -z "$snapshot" ]; then
  mkdir -p .wheelhouse || die 3 "could not make .wheelhouse"
  [ -f .wheelhouse/.gitignore ] || printf '*\n' > .wheelhouse/.gitignore
  snapshot=.wheelhouse/patrol.json
fi
old='null'
if [ -f "$snapshot" ]; then
  old=$(jq -c . "$snapshot" 2>/dev/null) || die 3 "the snapshot $snapshot isn't JSON: move it aside to start again"
fi

# One repository's state now: {prs, issues, ci}, keyed by number.
read_repo() {
  local r="$1" prs issues branch runs
  prs=$(gh pr list -R "$r" --state all --limit "$limit" \
    --json number,title,url,state,isDraft,baseRefName,mergeStateStatus,mergeCommit,statusCheckRollup 2>&1) || { echo "gh pr list: $prs" | head -1; return 1; }
  issues=$(gh issue list -R "$r" --state all --limit "$limit" --json number,title,url,state,stateReason 2>&1) || { echo "gh issue list: $issues" | head -1; return 1; }
  branch=$(gh repo view "$r" --json defaultBranchRef --jq .defaultBranchRef.name 2>&1) || { echo "gh repo view: $branch" | head -1; return 1; }
  runs=$(gh run list -R "$r" --branch "$branch" --limit 20 --json workflowName,status,conclusion,url,headSha 2>&1) || { echo "gh run list: $runs" | head -1; return 1; }
  jq -nc --argjson prs "$prs" --argjson issues "$issues" --arg branch "$branch" --argjson runs "$runs" \
    -f "$here/patrol-read.jq"
}

now='{}'; errors='[]'; status=0
for r in "${repos[@]}"; do
  if state=$(read_repo "$r"); then
    now=$(jq -c --arg r "$r" --argjson s "$state" '. + {($r): $s}' <<<"$now")
  else
    errors=$(jq -c --arg r "$r" --arg d "$state" '. + [{kind: "error", repo: $r, detail: $d}]' <<<"$errors")
    # Keep what the last run saw, so the next run compares with it.
    now=$(jq -c --arg r "$r" --argjson old "$old" '. + {($r): (($old // {}).repos[$r] // null)} | with_entries(select(.value != null))' <<<"$now")
    status=3
  fi
done

changes='[]'
if [ "$old" != null ]; then
  changes=$(jq -c --argjson old "$old" --argjson now "$now" -n -f "$here/patrol-diff.jq") || die 3 "could not compare with the snapshot"
fi

# How each newly merged pull request was merged: two parents is a merge
# commit; one is a squash (or a rebase, which looks the same).
merged=$(jq -c '[.[] | select(.kind == "pr-merged" and .mergeCommit != null)]' <<<"$changes")
if [ "$merged" != '[]' ]; then
  while IFS=$'\t' read -r r n oid; do
    parents=$(gh api "repos/$r/commits/$oid" --jq '.parents | length' 2>/dev/null) || parents=""
    case "$parents" in 2) m=merge ;; 1) m=squash ;; *) m="" ;; esac
    changes=$(jq -c --arg r "$r" --argjson n "$n" --arg m "$m" \
      'map(if .kind == "pr-merged" and .repo == $r and .number == $n then .method = (if $m == "" then null else $m end) else . end)' <<<"$changes")
  done < <(jq -r '.[] | [.repo, .number, .mergeCommit] | @tsv' <<<"$merged")
fi
changes=$(jq -c 'map(del(.mergeCommit))' <<<"$changes")

if [ "$dry" = false ]; then
  jq -nc --argjson repos "$now" '{repos: $repos}' > "$snapshot.new" && mv "$snapshot.new" "$snapshot" ||
    die 3 "could not write the snapshot $snapshot"
fi

jq -c --argjson e "$errors" '. + $e' <<<"$changes"
[ "$old" != null ] || [ "$dry" = true ] || echo "patrol: first run, snapshot saved to $snapshot; nothing to compare with yet" >&2
exit "$status"
