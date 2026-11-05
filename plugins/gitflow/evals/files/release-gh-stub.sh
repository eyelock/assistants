#!/usr/bin/env bash
# A gh for the release sandbox. release-setup.sh installs it as .eval/bin/gh,
# with @ORIGIN@, @LOG@ and @GIT@ replaced by the local bare origin, the stub
# log and the real git.
# It answers like GitHub would for the acme/widget repo: pull requests are kept
# in .eval/prs, merging one really merges it into origin (with plumbing, as
# the OS sandbox allows no clone), CI checks are green,
# and the release workflow has run for every v* tag origin holds.
# Every call is logged. Exit codes: 0 success, 1 a failed gh command.
set -uo pipefail

origin="@ORIGIN@"
log="@LOG@"
git() { "@GIT@" "$@"; }
state="$(dirname "$origin")/prs"
repo="acme/widget"
url="https://github.com/$repo"
touch "$state"

{
  printf 'gh'
  printf ' %q' "$@"
  printf '\n'
} >>"$log"

has() {
  local want="$1"
  shift
  for a in "$@"; do [[ "$a" == "$want" || "$a" == "$want="* ]] && return 0; done
  return 1
}

opt() {
  local want="$1"
  shift
  while (($#)); do
    case "$1" in
      "$want") echo "${2:-}"; return ;;
      "$want="*) echo "${1#*=}"; return ;;
    esac
    shift
  done
}

jq_filter() {
  local filter
  filter="$(opt --jq "$@")"
  [[ -z "$filter" ]] && filter="$(opt -q "$@")"
  if [[ -n "$filter" ]]; then jq -r "$filter"; else cat; fi
}

# The first positional argument, skipping flags and the values they take.
positional() {
  while (($#)); do
    case "$1" in
      --json | --jq | -q | --repo | -R | --template | -t | --title | -b | --body | -F | --body-file | -B | --base | -H | --head | -w | --workflow | -L | --limit | -i | --interval | -s | --subject | --branch | --commit | -c)
        shift 2 ;;
      -*) shift ;;
      *) echo "$1"; return ;;
    esac
  done
}

# release-failed-setup.sh tags a release whose widget/version.go is not gofmt-clean:
# the release workflow fails for a tag on such a tree, and passes for one on a clean tree.
rel_failed() {
  git --git-dir="$origin" show "$(latest_tag):widget/version.go" 2>/dev/null | grep -q 'Version="'
}

current_branch() { git branch --show-current 2>/dev/null; }

latest_tag() { git --git-dir="$origin" tag --sort=-v:refname --sort=-creatordate -l 'v*' | head -1; }

# A PR's line in the state file: number<TAB>head<TAB>base<TAB>state<TAB>title
find_pr() {
  local key="${1:-}"
  [[ -z "$key" ]] && key="$(current_branch)"
  key="${key#\#}"
  key="${key##*/pull/}"
  awk -F'\t' -v k="$key" '$1 == k || $2 == k' "$state" | tail -1
}

pr_json() {
  local line="$1" n head base st title
  IFS=$'\t' read -r n head base st title <<<"$line"
  jq -n --arg n "$n" --arg head "$head" --arg base "$base" --arg st "$st" --arg title "$title" --arg url "$url" '{
    number: ($n | tonumber), title: $title, state: $st, headRefName: $head, baseRefName: $base,
    url: "\($url)/pull/\($n)", isDraft: false,
    mergeable: (if $st == "OPEN" then "MERGEABLE" else "UNKNOWN" end),
    mergeStateStatus: (if $st == "OPEN" then "CLEAN" else "UNKNOWN" end),
    reviewDecision: "",
    statusCheckRollup: [
      {name: "Build", status: "COMPLETED", conclusion: "SUCCESS"},
      {name: "Test", status: "COMPLETED", conclusion: "SUCCESS"},
      {name: "Lint", status: "COMPLETED", conclusion: "SUCCESS"},
      {name: "All Clear", status: "COMPLETED", conclusion: "SUCCESS"},
      {name: "Verify PR source branch", status: "COMPLETED", conclusion: "SUCCESS"}
    ]
  }'
}

pr_checks() {
  printf 'Build\tpass\t1m12s\t%s/actions/runs/9120001/job/1\t\n' "$url"
  printf 'Test\tpass\t2m03s\t%s/actions/runs/9120001/job/2\t\n' "$url"
  printf 'Lint\tpass\t48s\t%s/actions/runs/9120001/job/3\t\n' "$url"
  printf 'Format\tpass\t21s\t%s/actions/runs/9120001/job/4\t\n' "$url"
  printf 'All Clear\tpass\t3s\t%s/actions/runs/9120001/job/5\t\n' "$url"
  if [[ "${1:-}" == main ]]; then
    printf 'Verify PR source branch\tpass\t4s\t%s/actions/runs/9120002/job/1\t\n' "$url"
  fi
}

pr_create() {
  local base head title n
  base="$(opt --base "$@")"
  [[ -z "$base" ]] && base="$(opt -B "$@")"
  [[ -z "$base" ]] && base=develop
  head="$(opt --head "$@")"
  [[ -z "$head" ]] && head="$(opt -H "$@")"
  [[ -z "$head" ]] && head="$(current_branch)"
  title="$(opt --title "$@")"
  [[ -z "$title" ]] && title="$(opt -t "$@")"
  [[ -z "$title" ]] && title="$head"
  if ! git --git-dir="$origin" rev-parse -q --verify "refs/heads/$head" >/dev/null; then
    echo "pull request create failed: GraphQL: Head sha can't be blank, Base sha can't be blank, No commits between $base and $head, Head ref must be a branch (createPullRequest)" >&2
    exit 1
  fi
  n=$((57 + $(wc -l <"$state")))
  printf '%s\t%s\t%s\tOPEN\t%s\n' "$n" "$head" "$base" "$title" >>"$state"
  echo
  echo "Creating pull request for $head into $base in $repo"
  echo
  echo "$url/pull/$n"
}

pr_merge() {
  local line n head base st title
  line="$(find_pr "$(positional "$@")")"
  if [[ -z "$line" ]]; then
    echo "no pull requests found for branch \"$(current_branch)\"" >&2
    exit 1
  fi
  IFS=$'\t' read -r n head base st title <<<"$line"
  if [[ "$st" != OPEN ]]; then
    echo "! Pull request #$n ($title) was already merged" >&2
    exit 1
  fi
  # Plumbing only: the OS sandbox forbids the clone a worktree merge would need.
  local o=(git --git-dir="$origin") tree commit
  if ! tree="$("${o[@]}" merge-tree --write-tree "refs/heads/$base" "refs/heads/$head" 2>/dev/null | head -1)"; then
    echo "X Pull request $repo#$n is not mergeable: the merge commit cannot be cleanly created." >&2
    exit 1
  fi
  if has --squash "$@" || has --rebase "$@"; then
    commit="$("${o[@]}" commit-tree "$tree" -p "refs/heads/$base" -m "$title (#$n)")"
  else
    commit="$("${o[@]}" commit-tree "$tree" -p "refs/heads/$base" -p "refs/heads/$head" \
      -m "Merge pull request #$n from acme/$head" -m "$title")"
  fi
  "${o[@]}" update-ref "refs/heads/$base" "$commit"
  if has --delete-branch "$@" || has -d "$@"; then "${o[@]}" update-ref -d "refs/heads/$head"; fi
  awk -F'\t' -v OFS='\t' -v n="$n" '$1 == n { $4 = "MERGED" } { print }' "$state" >"$state.tmp" && mv "$state.tmp" "$state"
  local how=Merged
  has --squash "$@" && how="Squashed and merged"
  has --rebase "$@" && how="Rebased and merged"
  echo "✓ $how pull request $repo#$n ($title)"
}

run_list() {
  local tag
  tag="$(latest_tag)"
  local wf
  wf="$(opt --workflow "$@")"
  [[ -z "$wf" ]] && wf="$(opt -w "$@")"
  local json concl=success
  rel_failed && concl=failure
  local branch
  branch="$(opt --branch "$@")"
  [[ -z "$branch" ]] && branch="$(opt -b "$@")"
  [[ -z "$branch" ]] && branch=develop
  json="$(jq -n --arg tag "$tag" --arg url "$url" --arg wf "$wf" --arg branch "$branch" --arg concl "$concl" '[
    if ($wf == "" or ($wf | test("release"; "i"))) then
      {databaseId: 9130001, status: "completed", conclusion: $concl, headBranch: $tag,
       displayTitle: "Release \($tag)", workflowName: "Release", event: "push",
       createdAt: "2026-10-06T09:14:02Z", url: "\($url)/actions/runs/9130001"}
    else empty end,
    if ($wf == "" or ($wf | test("ci"; "i"))) then
      {databaseId: 9120001, status: "completed", conclusion: "success", headBranch: $branch,
       displayTitle: "CI", workflowName: "CI", event: "push",
       createdAt: "2026-10-06T09:02:41Z", url: "\($url)/actions/runs/9120001"}
    else empty end
  ]')"
  if has --json "$@"; then
    jq_filter "$@" <<<"$json"
  else
    jq -r '.[] | [.status, .conclusion, .displayTitle, .workflowName, .headBranch, .event, (.databaseId | tostring), "2m14s", .createdAt] | @tsv' <<<"$json"
  fi
}

release_view() {
  local tag
  tag="$(positional "$@")"
  [[ -z "$tag" ]] && tag="$(latest_tag)"
  if ! git --git-dir="$origin" rev-parse -q --verify "refs/tags/$tag" >/dev/null || rel_failed; then
    echo "release not found" >&2
    exit 1
  fi
  local pre=false
  [[ "$tag" == *-* ]] && pre=true
  local json
  json="$(jq -n --arg tag "$tag" --arg url "$url" --argjson pre "$pre" '{
    tagName: $tag, name: $tag, isDraft: false, isPrerelease: $pre,
    publishedAt: "2026-10-06T09:16:40Z", url: "\($url)/releases/tag/\($tag)",
    author: {login: "github-actions[bot]"},
    assets: [{name: "widget_\($tag)_linux_amd64.tar.gz"}, {name: "widget_\($tag)_darwin_arm64.tar.gz"}, {name: "checksums.txt"}]
  }')"
  if has --json "$@"; then
    jq_filter "$@" <<<"$json"
  else
    jq -r '"title:\t\(.name)\ntag:\t\(.tagName)\ndraft:\tfalse\nprerelease:\t\(.isPrerelease)\nauthor:\t\(.author.login)\nurl:\t\(.url)\n--\n\(.assets | map("asset:\t\(.name)") | join("\n"))"' <<<"$json"
  fi
}

case "${1:-} ${2:-}" in
  "pr create") shift 2; pr_create "$@" ;;
  "pr merge") shift 2; pr_merge "$@" ;;
  "pr checks")
    shift 2
    line="$(find_pr "$(positional "$@")")"
    if [[ -z "$line" ]]; then echo "no pull requests found for branch \"$(current_branch)\"" >&2; exit 1; fi
    pr_checks "$(cut -f3 <<<"$line")"
    ;;
  "pr view")
    shift 2
    line="$(find_pr "$(positional "$@")")"
    if [[ -z "$line" ]]; then echo "no pull requests found for branch \"$(current_branch)\"" >&2; exit 1; fi
    if has --json "$@"; then
      pr_json "$line" | jq_filter "$@"
    else
      pr_json "$line" | jq -r '"\(.title) #\(.number)\n\(.state) • \(.headRefName) → \(.baseRefName)\nChecks: all passing\n\(.url)"'
    fi
    ;;
  "pr list")
    while IFS=$'\t' read -r n head base st title; do
      [[ "$st" == OPEN ]] && printf '%s\t%s\t%s\tOPEN\n' "$n" "$title" "$head"
    done <"$state"
    ;;
  "pr status") echo "Current branch: $(current_branch)" ;;
  "run list") shift 2; run_list "$@" ;;
  "run watch" | "run view")
    if rel_failed; then
      tag="$(latest_tag)"
      sha="$(git --git-dir="$origin" rev-parse --short "$tag^{commit}")"
      if has --log "$@" || has --log-failed "$@"; then
        echo "verify-ci	Check the CI status	2026-10-06T09:14:30Z Format check failed on $sha"
        echo "verify-ci	Check the CI status	2026-10-06T09:14:30Z widget/version.go needs gofmt"
        echo "verify-ci	Check the CI status	2026-10-06T09:14:31Z ##[error]Process completed with exit code 1."
      else
        echo "X Release $tag · 9130001"
        echo "Triggered via push about 2 minutes ago"
        echo
        echo "JOBS"
        echo "X Verify CI Passed in 12s (ID 1)"
        echo "- Build and Release (ID 2)"
        echo
        echo "To see what failed, try: gh run view 9130001 --log-failed"
      fi
      exit 0
    fi
    if has --log "$@" || has --log-failed "$@"; then
      echo "build-and-release	Create GitHub Release	2026-10-06T09:16:39Z ✓ Release $(latest_tag) published"
    else
      echo "✓ Release $(latest_tag) · 9130001"
      echo "Triggered via push about 2 minutes ago"
      echo
      echo "JOBS"
      echo "✓ Verify CI Passed in 41s (ID 1)"
      echo "✓ Build and Release in 1m33s (ID 2)"
      echo
      echo "✓ Run Release (9130001) completed with 'success'"
    fi
    ;;
  "release view") shift 2; release_view "$@" ;;
  "release list")
    for t in $(git --git-dir="$origin" tag --sort=-creatordate -l 'v*'); do
      pre=""
      [[ "$t" == *-* ]] && pre="Pre-release"
      printf '%s\t%s\t%s\t2026-10-06T09:16:40Z\n' "$t" "${pre:-Latest}" "$t"
    done
    ;;
  "release create")
    shift 2
    echo "$url/releases/tag/$(positional "$@")"
    ;;
  "repo view")
    if has --json "$@"; then
      jq -n --arg r "$repo" '{nameWithOwner: $r, name: "widget", owner: {login: "acme"}, defaultBranchRef: {name: "main"}, url: "https://github.com/\($r)"}' | jq_filter "$@"
    else
      printf 'name:\t%s\ndescription:\tWidget service\n' "$repo"
    fi
    ;;
  "auth status") echo "✓ Logged in to github.com account eval-user (GH_TOKEN)" ;;
  *) echo "(gh $* is not modelled in this sandbox; the call was recorded)" ;;
esac
