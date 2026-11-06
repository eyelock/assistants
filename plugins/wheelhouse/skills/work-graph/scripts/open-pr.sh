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
# Exit codes: 0 done, 1 bad args or refused, 2 not a Wheelhouse or the bead not found,
# 3 a tool (jq, bd, gh) is missing or failed.
set -uo pipefail

usage() {
  cat <<'EOF2'
Usage: open-pr.sh --bead <id> [--title <title>] [--body-file <file>] [--base <branch>]
                  [--repo <owner/name>] [--dir <wheelhouse repo>] [--dry-run]

Opens a draft pull request for the bead, from the current directory's repository, with the
bead's tracker item linked and its release set. Prints a JSON object: {"url", "item",
"release", "closing"}. Refuses a bead with no tracker item unless it is labelled housekeeping or its
repo: label is in tracker.json's exempt_repos (then it opens with no item, release or closing link,
and the JSON has "exempt": true).
--dir is the Wheelhouse (default: the current directory); --dry-run prints what it would run, and
needs no --title. The JSON also names "item_name", "release_name" and "relation" ("closes" when the
bead is the last open bead on the item, "part-of" otherwise, "" with no tracker item): a dispatch
note asks this for the same answer the PR will give.
EOF2
}

die() { echo "$2" >&2; exit "$1"; }
refuse() { echo "open-pr: refused: $1" >&2; jq -n --arg r "$1" '{refused: $r}'; exit 1; }

bead=""; title=""; body_file=""; base=""; repo=""; dir="."; dry=false
while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --dry-run) dry=true; shift ;;
    --bead | --title | --body-file | --base | --repo | --dir)
      [ $# -ge 2 ] || { usage >&2; exit 1; }
      case "$1" in
        --bead) bead="$2" ;; --title) title="$2" ;; --body-file) body_file="$2" ;;
        --base) base="$2" ;; --repo) repo="$2" ;; --dir) dir="$2" ;;
      esac
      shift 2 ;;
    *) usage >&2; exit 1 ;;
  esac
done
[ -n "$bead" ] || { usage >&2; exit 1; }
$dry || [ -n "$title" ] || { usage >&2; exit 1; }
[ -z "$body_file" ] || [ -f "$body_file" ] || die 2 "open-pr: no such body file: $body_file"
command -v jq >/dev/null || die 3 "open-pr: jq is not installed"
command -v bd >/dev/null || die 3 "open-pr: bd (Beads) is not installed"
command -v gh >/dev/null || die 3 "open-pr: gh is not installed"
[ -d "$dir/.beads" ] || die 2 "open-pr: $dir is not a Wheelhouse (no .beads)"
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# The bead.
shown=$(cd "$dir" && bd show "$bead" --json 2>/dev/null) || die 2 "open-pr: no bead $bead"
ref=$(jq -r '(.data? // .) | (if type == "array" then .[0] else . end) | .external_ref // ""' <<<"$shown")
housekeeping=$(jq -r '(.data? // .) | (if type == "array" then .[0] else . end) | [(.labels // [])[] | select(. == "housekeeping")] | length' <<<"$shown")

# The tracker config.
kind=none
if [ -f "$dir/tracker.json" ]; then
  kind=$(jq -er '.kind' "$dir/tracker.json" 2>/dev/null) || die 3 "open-pr: $dir/tracker.json is not valid, or has no kind"
  # kind names an adapter file, so it must be a plain word, never a path.
  printf '%s\n' "$kind" | grep -Eq '^[a-z0-9_-]+$' || die 3 "open-pr: tracker.json kind must be lower-case letters, digits, - or _"
fi

# Exempt by repository: the bead's repo: label is in the config's exempt_repos. A list that is not
# an array of strings is a fault, never "nothing exempt".
exempt=false
if [ "$kind" != none ]; then
  jq -e '(.exempt_repos // []) | type == "array" and all(type == "string")' "$dir/tracker.json" >/dev/null 2>&1 ||
    die 3 "open-pr: tracker.json exempt_repos must be a list of repository names"
  hit=$(jq -r --argjson b "$shown" '
    (.exempt_repos // []) as $ex
    | ($b | (.data? // .) | (if type == "array" then .[0] else . end) | [(.labels // [])[] | select(startswith("repo:")) | ltrimstr("repo:")]) as $repos
    | [$repos[] | select(. as $r | $ex | index($r))] | length' "$dir/tracker.json") ||
    die 3 "open-pr: could not read exempt_repos"
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
  [ -n "$pattern" ] || die 3 "open-pr: tracker.json has no item.pattern; refusing to run its commands"
  printf '%s\n' "$ref" | grep -Eq -- "$pattern" ||
    refuse "bead $bead's external_ref does not look like a tracker $name (expected to match $pattern)"
  case "$ref" in *$'\n'*) refuse "bead $bead's external_ref spans several lines" ;; esac
  item="$ref"
  adapter="$here/tracker-$kind.sh"; [ -f "$adapter" ] || adapter="$here/tracker-generic.sh"
  release=$(bash "$adapter" release "$item") || die 3 "open-pr: the $kind adapter could not read the release of $item"
  [ -n "$release" ] || refuse "the tracker $name $item has no $rname: set it in the tracker, then open the PR"

  # Is this the last open bead on the item? Both sides go through the adapter to a canonical item
  # id first, so a sibling written in another case or short form (owner/repo#N) still counts.
  mine=$(bash "$adapter" canon "$item") || die 3 "open-pr: the $kind adapter failed to canonicalise $item"
  # Capture each step on its own, so a failing bd or jq is a fault (exit 3), never a count of 0
  # that would write "Closes" while other beads are open on the item.
  listing=$(cd "$dir" && bd list --all --json 2>/dev/null) || die 3 "open-pr: bd list failed"
  # A bead in an exempt repository is no sibling: its PR carries no closing link, so it never holds
  # the item open. (Its external_ref may name the same item as this bead's.)
  exlist=$(jq -c '(.exempt_repos // [])' "$dir/tracker.json") || die 3 "open-pr: could not read exempt_repos"
  refs=$(jq -r --arg id "$bead" --argjson ex "$exlist" \
    '(.data? // .)[] | select(.id != $id and .status != "closed")
     | select(([(.labels // [])[] | select(startswith("repo:")) | ltrimstr("repo:") | select(. as $r | $ex | index($r))] | length) == 0)
     | .external_ref // empty' <<<"$listing") ||
    die 3 "open-pr: could not read bd list's output"
  others=0
  while IFS= read -r sib; do
    [ -n "$sib" ] || continue
    c=$(bash "$adapter" canon "$sib") || die 3 "open-pr: the $kind adapter failed to canonicalise $sib"
    if [ "$c" = "$mine" ]; then others=$((others + 1)); fi
  done <<<"$refs"
  last=more; [ "$others" -eq 0 ] && last=last

  [ -z "$repo" ] && repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
  relation=part-of; [ "$last" = last ] && relation=closes
  closing=$(bash "$adapter" closing "$item" "$last" "$repo") || die 3 "open-pr: the $kind adapter failed to write the closing link"
  while IFS= read -r f; do [ -n "$f" ] && flags+=("$f"); done < <(bash "$adapter" pr-flags "$release")
fi

body=""; [ -z "$body_file" ] || body=$(cat "$body_file")
[ -z "$closing" ] || body="$body"$'\n\n'"$closing"

args=(pr create --draft --title "$title" --body "$body")
[ -z "$base" ] || args+=(--base "$base")
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
url=$(gh "${args[@]}") || die 3 "open-pr: gh pr create failed"
# Note the PR on the bead, so the dispatcher, the wake and the dead-claim check all find an open
# pull request the same way: a note line "PR: <url>". A failed note does not undo the PR.
(cd "$dir" && bd note "$bead" "PR: $url" >/dev/null) ||
  echo "open-pr: opened $url but could not note it on $bead; run: bd note $bead \"PR: $url\"" >&2
jq -n --arg url "$url" --arg item "$item" --arg release "$release" --arg closing "$closing" \
  --arg iname "$name" --arg rname "$rname" --arg relation "$relation" --argjson exempt "$exempt" \
  '{url: $url, exempt: $exempt, item: $item, item_name: $iname, release: $release, release_name: $rname, relation: $relation, closing: $closing}'
