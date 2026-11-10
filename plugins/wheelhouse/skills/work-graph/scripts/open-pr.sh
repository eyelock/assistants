#!/usr/bin/env bash
# Opens a draft pull request for a bead, with the bead's tracker item and release.
#
# The only way a worker opens a PR. It reads the bead's external_ref, checks it against the
# Wheelhouse's tracker config (tracker.json), reads the item's release, asks the tracker adapter
# for the closing link and the flags that set the release on the PR, and runs `gh pr create
# --draft` in the current directory (the repository's worktree).
#
# The config: <wheelhouse>/tracker.json (see references/tracker.md). No file, or kind "none":
# no tracker, so the PR opens with no item and no release. With a tracker the script REFUSES
# (exit 1, nothing opened) when:
#   - the bead has no external_ref and is not labelled housekeeping;
#   - the external_ref does not match item.pattern (a config with no pattern is a fault, exit 3);
#   - the item has no release.
# A bead labelled housekeeping that has no external_ref opens as if there were no tracker.
# A bead whose repo:<name> label is named in tracker.json's exempt_repos (a list of repository
# names) is exempt by repository: it opens as if there were no tracker, whatever its external_ref
# says, with no item, no closing link and no release. The check comes before any adapter is
# called, so it holds for every tracker kind.
#
# The adapter: tracker-<kind>.sh beside this script (tracker-github.sh; tracker-generic.sh for
# any kind without its own). It is the one place that knows a tracker's closing-link words and
# how to set a release on a PR. It is called as
#   tracker-<kind>.sh closing <item> <last|more> <pr-repo>   prints the closing line
#   tracker-<kind>.sh pr-flags <release>                     prints gh pr create args, one a line
#   tracker-<kind>.sh release <item>                         prints the item's release, empty if none
#   tracker-<kind>.sh canon <ref>                            prints the canonical item id
#   tracker-<kind>.sh state <item>                           prints open, closed or unknown (sweeps)
# <last> means this bead is the last open bead on the item; <more>, that others remain.
#
# Nothing in tracker.json is run. The release is read by the adapter's own code (release <item>),
# after the reference has matched item.pattern (required) and again the adapter's strict form.
#
# A bead whose external_ref is a pull request URL is a review fix: --dry-run reports it ("review_fix":
# true, exit 0) and a real run refuses (exit 1), since the fix goes to the existing pull request.
#
# Exit codes: 0 done, 1 bad args or refused, 2 not a Wheelhouse or the bead not found,
# 3 a tool (jq, bd, gh) is missing or failed.
set -uo pipefail

usage() {
  cat <<'EOF2'
Usage: open-pr.sh --bead <id> [--title <title>] [--body-file <file>] [--base <branch>]
                  [--head <branch>] [--repo <owner/name>] [--dir <wheelhouse repo>] [--dry-run]

Opens a draft pull request for the bead, from the current directory's repository, with the
bead's tracker item linked and its release set. Prints a JSON object: {"url", "item",
"release", "closing"}. Refuses a bead with no tracker item unless it is labelled housekeeping or its
repo: label is in tracker.json's exempt_repos (then it opens with no item, release or closing link,
and the JSON has "exempt": true).
--dir is the Wheelhouse (default: the current directory); --dry-run prints what it would run, and
needs no --title. --title defaults to the bead's title.
--head is the remote branch to open the PR from: by default the current branch's upstream branch
when its name differs from the local one (a seat that pushed another seat's branch from its own
worktree), else gh's own choice. --base defaults to the repository's default branch (gh's choice);
pass it for a gitflow repository whose PRs target develop. The JSON also names "item_name", "release_name" and "relation" ("closes" when the
bead is the last open bead on the item, "part-of" otherwise, "" with no tracker item): a dispatch
note asks this for the same answer the PR will give.
EOF2
}

refuse() { echo "open-pr: refused: $1" >&2; jq -n --arg r "$1" '{refused: $r}'; exit 1; }

WL_PREFIX="open-pr: "
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/wheelhouse-lib.sh" "$here/../../../lib/wheelhouse-lib.sh"; do
  # shellcheck source=../../../lib/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found beside $0 or in the plugin's lib folder" >&2; exit 3; }
bead=""; title=""; body_file=""; base=""; head=""; repo=""; dir="."; dry=false
while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --dry-run) dry=true; shift ;;
    --bead | --title | --body-file | --base | --head | --repo | --dir)
      [ $# -ge 2 ] || { usage >&2; exit 1; }
      case "$1" in
        --bead) bead="$2" ;; --title) title="$2" ;; --body-file) body_file="$2" ;;
        --base) base="$2" ;; --head) head="$2" ;; --repo) repo="$2" ;; --dir) dir="$2" ;;
      esac
      shift 2 ;;
    *) usage >&2; exit 1 ;;
  esac
done
[ -n "$bead" ] || { usage >&2; exit 1; }
[ -z "$body_file" ] || [ -f "$body_file" ] || die 2 "no such body file: $body_file"
need jq
need bd
need gh
[ -d "$dir/.beads" ] || die 2 "$dir is not a Wheelhouse (no .beads)"

# The bead.
shown=$(cd "$dir" && limited "$WL_BD_SECS" bd show "$bead" --json 2>/dev/null) || die 2 "no bead $bead"
shown=$(bd_first <<<"$shown")
ref=$(jq -r '.external_ref // ""' <<<"$shown")
housekeeping=$(jq -r '[(.labels // [])[] | select(. == "housekeeping")] | length' <<<"$shown")

# A review fix: its external_ref is the URL of the pull request it fixes, not a tracker item. It
# pushes to that PR and opens none, so there is nothing to link: a dry run reports it, and a real
# run refuses (push to the existing pull request instead).
if printf '%s\n' "$ref" | grep -Eq '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+$'; then
  if $dry; then
    jq -n --arg pr "$ref" '{dry_run: true, review_fix: true, pr: $pr, exempt: true, item: "", release: "", closing: "", relation: "", gh: []}'
    exit 0
  fi
  refuse "bead $bead is a review fix: its external_ref is the pull request $ref, which it pushes to; open no new one"
fi

# The tracker config.
kind=none
if [ -f "$dir/tracker.json" ]; then
  kind=$(jq -er '.kind' "$dir/tracker.json" 2>/dev/null) || die 3 "$dir/tracker.json is not valid, or has no kind"
  # kind names an adapter file, so it must be a plain word, never a path.
  printf '%s\n' "$kind" | grep -Eq '^[a-z0-9_-]+$' || die 3 "tracker.json kind must be lower-case letters, digits, - or _"
fi

# Exempt by repository: the bead's repo: label is in the config's exempt_repos. A list that is not
# an array of strings is a fault, never "nothing exempt".
exempt=false
if [ "$kind" != none ]; then
  jq -e '(.exempt_repos // []) | type == "array" and all(type == "string")' "$dir/tracker.json" >/dev/null 2>&1 ||
    die 3 "tracker.json exempt_repos must be a list of repository names"
  hit=$(jq -r --argjson b "$shown" '
    (.exempt_repos // []) as $ex
    | ($b | [(.labels // [])[] | select(startswith("repo:")) | ltrimstr("repo:")]) as $repos
    | [$repos[] | select(. as $r | $ex | index($r))] | length' "$dir/tracker.json") ||
    die 3 "could not read exempt_repos"
  [ "$hit" -gt 0 ] && exempt=true
fi

item=""; release=""; closing=""; flags=(); name=""; rname=""; relation=""
if [ "$kind" != none ] && ! $exempt && { [ -n "$ref" ] || [ "$housekeeping" -eq 0 ]; }; then
  name=$(jq -r '.item.name // "item"' "$dir/tracker.json")
  rname=$(jq -r '.release.name // "release"' "$dir/tracker.json")
  [ -n "$ref" ] || refuse "bead $bead has no external_ref: a build bead links its tracker $name (file the $name, then set the bead's external_ref), or carries the housekeeping label if it has none"
  # The pattern is required, and checked before the adapter is called. The adapter checks the
  # reference again against its own strict form, and passes it to the tracker's CLI as one argument.
  pattern=$(jq -r '.item.pattern // empty' "$dir/tracker.json")
  [ -n "$pattern" ] || die 3 "tracker.json has no item.pattern; refusing to run its commands"
  printf '%s\n' "$ref" | grep -Eq -- "$pattern" ||
    refuse "bead $bead's external_ref does not look like a tracker $name (expected to match $pattern)"
  case "$ref" in *$'\n'*) refuse "bead $bead's external_ref spans several lines" ;; esac
  item="$ref"
  adapter="$here/tracker-$kind.sh"; [ -f "$adapter" ] || adapter="$here/tracker-generic.sh"
  release=$(bash "$adapter" release "$item") || die 3 "the $kind adapter could not read the release of $item"
  [ -n "$release" ] || refuse "the tracker $name $item has no $rname: set it in the tracker, then open the PR"

  # Is this the last open bead on the item? Both sides go through the adapter to a canonical item
  # id first, so a sibling written in another case or short form (owner/repo#N) still counts.
  mine=$(bash "$adapter" canon "$item") || die 3 "the $kind adapter failed to canonicalise $item"
  # Capture each step on its own, so a failing bd or jq is a fault (exit 3), never a count of 0
  # that would write "Closes" while other beads are open on the item.
  listing=$(cd "$dir" && limited "$WL_BD_SECS" bd list --all --json 2>/dev/null) || die 3 "bd list failed"
  # A bead in an exempt repository is no sibling: its PR carries no closing link, so it never holds
  # the item open. (Its external_ref may name the same item as this bead's.)
  exlist=$(jq -c '(.exempt_repos // [])' "$dir/tracker.json") || die 3 "could not read exempt_repos"
  refs=$(bd_data <<<"$listing" | jq -r --arg id "$bead" --argjson ex "$exlist" \
    '.[] | select(.id != $id and .status != "closed")
     | select(([(.labels // [])[] | select(startswith("repo:")) | ltrimstr("repo:") | select(. as $r | $ex | index($r))] | length) == 0)
     | .external_ref // empty') ||
    die 3 "could not read bd list's output"
  others=0
  while IFS= read -r sib; do
    [ -n "$sib" ] || continue
    c=$(bash "$adapter" canon "$sib") || die 3 "the $kind adapter failed to canonicalise $sib"
    if [ "$c" = "$mine" ]; then others=$((others + 1)); fi
  done <<<"$refs"
  last="more"; [ "$others" -eq 0 ] && last=last

  [ -z "$repo" ] && repo=$(limited "$WL_GH_SECS" gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
  relation=part-of; [ "$last" = last ] && relation=closes
  closing=$(bash "$adapter" closing "$item" "$last" "$repo") || die 3 "the $kind adapter failed to write the closing link"
  while IFS= read -r f; do [ -n "$f" ] && flags+=("$f"); done < <(bash "$adapter" pr-flags "$release")
fi

# The title defaults to the bead's own.
if [ -z "$title" ]; then
  title=$(jq -r '.title // ""' <<<"$shown")
  $dry || [ -n "$title" ] || { usage >&2; exit 1; }
fi
# The head: when the local branch's upstream has another name (a seat pushed another seat's branch
# from its own worktree), gh would look for the local name on the remote and fail. Name the
# upstream's branch instead.
if [ -z "$head" ]; then
  up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || up=""
  cur=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || cur=""
  if [ -n "$up" ] && [ -n "$cur" ]; then
    remote_branch="${up#*/}"
    [ "$remote_branch" = "$cur" ] || head="$remote_branch"
  fi
fi

body=""; [ -z "$body_file" ] || body=$(cat "$body_file")
[ -z "$closing" ] || body="$body"$'\n\n'"$closing"

args=(pr create --draft --title "$title" --body "$body")
[ -z "$base" ] || args+=(--base "$base")
[ -z "$head" ] || args+=(--head "$head")
[ -z "$repo" ] || args+=(--repo "$repo")
[ ${#flags[@]} -eq 0 ] || args+=("${flags[@]}")

if $dry; then
  ghjson='[]'
  for a in "${args[@]}"; do ghjson=$(jq -c --arg a "$a" '. + [$a]' <<<"$ghjson"); done
  jq -n --arg item "$item" --arg release "$release" --arg closing "$closing" --argjson gh "$ghjson" \
    --arg iname "$name" --arg rname "$rname" --arg relation "$relation" --argjson exempt "$exempt" \
    '{dry_run: true, exempt: $exempt, item: $item, item_name: $iname, release: $release, release_name: $rname, relation: $relation, closing: $closing, gh: $gh}'
  exit 0
fi
url=$(limited "$WL_GH_SECS" gh "${args[@]}") || die 3 "gh pr create failed"
# Note the PR on the bead, so the dispatcher, the wake and the dead-claim check all find an open
# pull request the same way: a note line "PR: <url>". A failed note does not undo the PR.
(cd "$dir" && limited "$WL_BD_SECS" bd note "$bead" "PR: $url" >/dev/null) ||
  echo "open-pr: opened $url but could not note it on $bead; run: bd note $bead \"PR: $url\"" >&2
jq -n --arg url "$url" --arg item "$item" --arg release "$release" --arg closing "$closing" \
  --arg iname "$name" --arg rname "$rname" --arg relation "$relation" --argjson exempt "$exempt" \
  '{url: $url, exempt: $exempt, item: $item, item_name: $iname, release: $release, release_name: $rname, relation: $relation, closing: $closing}'
