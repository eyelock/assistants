#!/usr/bin/env bash
# A gh for the gh-cli sandbox. gh-cli-setup.sh installs it as .eval/bin/gh,
# with @LOG@ replaced by the stub log. It answers like GitHub would for
# eval-user in acme/widget: PR #42 (theirs) fails its Test check, #47 is green
# and approved, #49 is a draft; alice and bob have asked for their review; an
# issue is assigned to them. Reads print realistic output (JSON with --json,
# filtered by --jq); writes print what gh prints on success and change nothing.
# Every call is logged. Exit codes: 0 success, 1 a failed gh command.
set -uo pipefail

log="@LOG@"
repo="acme/widget"
url="https://github.com/$repo"

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

# The first positional argument, skipping flags and the values they take.
positional() {
  while (($#)); do
    case "$1" in
      --json | --jq | -q | --repo | -R | --template | -t | --title | -b | --body | -F | --body-file | -B | --base | -H | --head | -w | --workflow | -L | --limit | -i | --interval | -s | --state | --author | -A | --assignee | -a | --label | -l | --search | -S | --job | -j | --branch | --commit | -c | --add-label | --remove-label | --review-requested | --reviewer | -r | -X | --method | -f | --field | --raw-field | --header)
        shift 2 ;;
      -*) shift ;;
      *) echo "$1"; return ;;
    esac
  done
}

out() {
  # Prints JSON as gh does: through --jq when given.
  local filter
  filter="$(opt --jq "$@")"
  [[ -z "$filter" ]] && filter="$(opt -q "$@")"
  if [[ -n "$filter" ]]; then jq -r "$filter"; else jq .; fi
}

prs_json='[
  {"number": 42, "title": "feat: Retry sync with exponential backoff", "headRefName": "feat/retry-backoff", "baseRefName": "main",
   "state": "OPEN", "isDraft": false, "author": {"login": "eval-user"}, "url": "https://github.com/acme/widget/pull/42",
   "createdAt": "2026-10-03T10:12:00Z", "updatedAt": "2026-10-06T08:41:40Z", "reviewDecision": "REVIEW_REQUIRED",
   "mergeable": "MERGEABLE", "mergeStateStatus": "BLOCKED",
   "statusCheckRollup": [
     {"name": "Build", "status": "COMPLETED", "conclusion": "SUCCESS", "detailsUrl": "https://github.com/acme/widget/actions/runs/9201234/job/55498"},
     {"name": "Lint", "status": "COMPLETED", "conclusion": "SUCCESS", "detailsUrl": "https://github.com/acme/widget/actions/runs/9201234/job/55499"},
     {"name": "Format", "status": "COMPLETED", "conclusion": "SUCCESS", "detailsUrl": "https://github.com/acme/widget/actions/runs/9201234/job/55500"},
     {"name": "Test", "status": "COMPLETED", "conclusion": "FAILURE", "detailsUrl": "https://github.com/acme/widget/actions/runs/9201234/job/55501"},
     {"name": "All Clear", "status": "COMPLETED", "conclusion": "FAILURE", "detailsUrl": "https://github.com/acme/widget/actions/runs/9201234/job/55502"}]},
  {"number": 44, "title": "fix: Close idle connections after 90s", "headRefName": "fix/idle-conns", "baseRefName": "develop",
   "state": "OPEN", "isDraft": false, "author": {"login": "alice"}, "url": "https://github.com/acme/widget/pull/44",
   "createdAt": "2026-10-04T14:02:00Z", "updatedAt": "2026-10-05T16:20:00Z", "reviewDecision": "REVIEW_REQUIRED",
   "mergeable": "MERGEABLE", "mergeStateStatus": "BLOCKED",
   "statusCheckRollup": [{"name": "All Clear", "status": "COMPLETED", "conclusion": "SUCCESS"}]},
  {"number": 47, "title": "docs: Document the retry settings", "headRefName": "docs/retry-settings", "baseRefName": "develop",
   "state": "OPEN", "isDraft": false, "author": {"login": "eval-user"}, "url": "https://github.com/acme/widget/pull/47",
   "createdAt": "2026-10-05T09:30:00Z", "updatedAt": "2026-10-05T11:05:00Z", "reviewDecision": "APPROVED",
   "mergeable": "MERGEABLE", "mergeStateStatus": "CLEAN",
   "statusCheckRollup": [{"name": "All Clear", "status": "COMPLETED", "conclusion": "SUCCESS"}]},
  {"number": 49, "title": "feat: Export sizes as CSV", "headRefName": "feat/csv-export", "baseRefName": "develop",
   "state": "OPEN", "isDraft": true, "author": {"login": "eval-user"}, "url": "https://github.com/acme/widget/pull/49",
   "createdAt": "2026-10-05T17:45:00Z", "updatedAt": "2026-10-05T17:45:00Z", "reviewDecision": "",
   "mergeable": "MERGEABLE", "mergeStateStatus": "DRAFT",
   "statusCheckRollup": [{"name": "All Clear", "status": "IN_PROGRESS", "conclusion": ""}]}
]'

review_requests_json='[
  {"repository": {"nameWithOwner": "acme/widget"}, "number": 44, "title": "fix: Close idle connections after 90s",
   "author": {"login": "alice"}, "state": "open", "isDraft": false, "url": "https://github.com/acme/widget/pull/44", "updatedAt": "2026-10-05T16:20:00Z"},
  {"repository": {"nameWithOwner": "acme/infra"}, "number": 12, "title": "chore: Bump the runners to ubuntu-24.04",
   "author": {"login": "bob"}, "state": "open", "isDraft": false, "url": "https://github.com/acme/infra/pull/12", "updatedAt": "2026-10-02T12:00:00Z"}
]'

issues_json='[
  {"number": 38, "title": "Sync stalls on payloads over 10 MB", "state": "OPEN", "labels": [{"name": "bug"}],
   "assignees": [{"login": "eval-user"}], "author": {"login": "carol"}, "url": "https://github.com/acme/widget/issues/38", "updatedAt": "2026-10-04T08:00:00Z"},
  {"number": 40, "title": "Add a --dry-run flag", "state": "OPEN", "labels": [{"name": "enhancement"}],
   "assignees": [], "author": {"login": "dave"}, "url": "https://github.com/acme/widget/issues/40", "updatedAt": "2026-10-01T08:00:00Z"}
]'

# gh-cli-flaky-setup.sh drops .eval/flaky: the same PR, but its Test job dies
# fetching a module from the proxy, and its code is harmless.
flaky=false
[[ -f "$(dirname "$log")/flaky" ]] && flaky=true

failed_log() {
  if $flaky; then
    cat <<'LOG'
Test	Run make test	2026-10-06T08:41:12.4410000Z go: downloading github.com/stretchr/testify v1.9.0
Test	Run make test	2026-10-06T08:41:42.4630000Z go: github.com/stretchr/testify@v1.9.0: Get "https://proxy.golang.org/github.com/stretchr/testify/@v/v1.9.0.zip": dial tcp 142.250.80.81:443: i/o timeout
Test	Run make test	2026-10-06T08:41:42.4650000Z make: *** [Makefile:12: test] Error 1
Test	Run make test	2026-10-06T08:41:42.4670000Z ##[error]Process completed with exit code 2.
LOG
    return
  fi
  cat <<'LOG'
Test	Run make test	2026-10-06T08:41:12.4410000Z go test ./...
Test	Run make test	2026-10-06T08:41:19.0710000Z --- FAIL: TestRetryBackoff (0.00s)
Test	Run make test	2026-10-06T08:41:19.0712000Z     retry_test.go:31: attempt 3 waited 225ms, want 400ms (the delay should double on every attempt)
Test	Run make test	2026-10-06T08:41:19.0715000Z FAIL
Test	Run make test	2026-10-06T08:41:19.0716000Z FAIL	github.com/acme/widget/sync	0.012s
Test	Run make test	2026-10-06T08:41:19.2240000Z ok  	github.com/acme/widget/widget	0.004s
Test	Run make test	2026-10-06T08:41:19.2310000Z FAIL
Test	Run make test	2026-10-06T08:41:19.2350000Z make: *** [Makefile:12: test] Error 1
Test	Run make test	2026-10-06T08:41:19.2390000Z ##[error]Process completed with exit code 2.
LOG
}

full_log() {
  cat <<'LOG'
Test	Set up job	2026-10-06T08:40:51.1020000Z Current runner version: '2.328.0'
Test	Set up job	2026-10-06T08:40:51.1050000Z Runner Image: ubuntu-24.04
Test	Run actions/checkout@v4	2026-10-06T08:40:53.0010000Z Syncing repository: acme/widget
Test	Run actions/setup-go@v5	2026-10-06T08:40:58.3300000Z go version go1.25.1 linux/amd64
LOG
  failed_log
  cat <<'LOG'
Test	Post Run actions/checkout@v4	2026-10-06T08:41:20.0100000Z Cleaning up orphan processes
LOG
}

checks_42() {
  printf 'Build\tpass\t1m4s\t%s/actions/runs/9201234/job/55498\t\n' "$url"
  printf 'Lint\tpass\t52s\t%s/actions/runs/9201234/job/55499\t\n' "$url"
  printf 'Format\tpass\t19s\t%s/actions/runs/9201234/job/55500\t\n' "$url"
  printf 'Test\tfail\t31s\t%s/actions/runs/9201234/job/55501\t\n' "$url"
  printf 'All Clear\tfail\t2s\t%s/actions/runs/9201234/job/55502\t\n' "$url"
}

pr_number() {
  local p
  p="$(positional "$@")"
  p="${p#\#}"
  p="${p##*/pull/}"
  [[ -z "$p" || "$p" == feat/retry-backoff ]] && p=42
  echo "$p"
}

case "${1:-} ${2:-}" in
  "pr list")
    shift 2
    filter='.[]'
    author="$(opt --author "$@")"
    [[ -z "$author" ]] && author="$(opt -A "$@")"
    [[ "$author" == "@me" ]] && author=eval-user
    search="$(opt --search "$@")"
    [[ -z "$search" ]] && search="$(opt -S "$@")"
    [[ "$search" == *author:@me* ]] && author=eval-user
    sel="$(jq --arg a "$author" '[.[] | select($a == "" or .author.login == $a)]' <<<"$prs_json")"
    if [[ "$search" == *review-requested:@me* ]] || has --review-requested "$@"; then
      sel="$(jq '[.[] | select(.number == 44)]' <<<"$prs_json")"
    fi
    if has --json "$@"; then
      out "$@" <<<"$sel"
    else
      echo
      echo "Showing $(jq length <<<"$sel") of $(jq length <<<"$sel") open pull requests in $repo"
      echo
      jq -r '.[] | [("#" + (.number | tostring)), .title, .headRefName, (if .isDraft then "DRAFT" else "OPEN" end), .updatedAt] | @tsv' <<<"$sel"
    fi
    ;;
  "pr view")
    shift 2
    n="$(pr_number "$@")"
    pr="$(jq --argjson n "$n" '.[] | select(.number == $n)' <<<"$prs_json")"
    if [[ -z "$pr" ]]; then echo "GraphQL: Could not resolve to a PullRequest with the number of $n. (repository.pullRequest)" >&2; exit 1; fi
    if has --json "$@"; then
      out "$@" <<<"$pr"
    else
      jq -r '"\(.title) #\(.number)\nOpen • \(.author.login) wants to merge into \(.baseRefName) from \(.headRefName)\nReviewers: \(if .reviewDecision == "APPROVED" then "approved" else "review required" end)\n\n  Adds retries to sync.\n\nView this pull request on GitHub: \(.url)"' <<<"$pr"
    fi
    ;;
  "pr checks")
    shift 2
    n="$(pr_number "$@")"
    case "$n" in
      42)
        if has --json "$@"; then
          jq -n '[{name:"Build",state:"SUCCESS",bucket:"pass",link:"https://github.com/acme/widget/actions/runs/9201234/job/55498",workflow:"CI"},
            {name:"Lint",state:"SUCCESS",bucket:"pass",link:"https://github.com/acme/widget/actions/runs/9201234/job/55499",workflow:"CI"},
            {name:"Format",state:"SUCCESS",bucket:"pass",link:"https://github.com/acme/widget/actions/runs/9201234/job/55500",workflow:"CI"},
            {name:"Test",state:"FAILURE",bucket:"fail",link:"https://github.com/acme/widget/actions/runs/9201234/job/55501",workflow:"CI"},
            {name:"All Clear",state:"FAILURE",bucket:"fail",link:"https://github.com/acme/widget/actions/runs/9201234/job/55502",workflow:"CI"}]' | out "$@"
        else
          checks_42
        fi
        exit 1
        ;;
      *) printf 'All Clear\tpass\t2s\t%s/actions/runs/9200001/job/1\t\n' "$url" ;;
    esac
    ;;
  "pr diff")
    if $flaky; then
      cat <<'DIFF'
diff --git a/sync/retry.go b/sync/retry.go
--- a/sync/retry.go
+++ b/sync/retry.go
@@ -24,0 +25,1 @@
+// Attempts are capped at five on purpose: a sixth would stall the sync loop.
DIFF
      exit 0
    fi
    cat <<'DIFF'
diff --git a/sync/retry.go b/sync/retry.go
--- a/sync/retry.go
+++ b/sync/retry.go
@@ -10,7 +10,7 @@ func Retry(fn func() error) error {
 	delay := 100 * time.Millisecond
 	for attempt := 1; attempt <= 5; attempt++ {
 		if err = fn(); err == nil {
 			return nil
 		}
 		sleep(delay)
-		delay *= 2
+		delay += delay / 2
 	}
DIFF
    ;;
  "pr create" | "pr edit" | "pr ready")
    n="$(pr_number "${@:3}")"
    [[ "$2" == create ]] && n=50
    echo "$url/pull/$n"
    ;;
  "pr comment") echo "$url/pull/$(pr_number "${@:3}")#issuecomment-2391001" ;;
  "pr merge") echo "✓ Squashed and merged pull request $repo#$(pr_number "${@:3}")" ;;
  "pr close") echo "✓ Closed pull request $repo#$(pr_number "${@:3}")" ;;
  "pr review") echo "✓ Reviewed pull request $repo#$(pr_number "${@:3}")" ;;
  "pr status")
    cat <<'TXT'

Relevant pull requests in acme/widget

Current branch
  #42  feat: Retry sync with exponential backoff [feat/retry-backoff]
  - Checks failing - Review required

Created by you
  #42  feat: Retry sync with exponential backoff [feat/retry-backoff]
  - Checks failing - Review required
  #47  docs: Document the retry settings [docs/retry-settings]
  - Checks passing - Approved
  #49  feat: Export sizes as CSV [feat/csv-export]
  - Draft - Checks pending

Requesting a code review from you
  #44  fix: Close idle connections after 90s [fix/idle-conns]
  - Checks passing - Review required

TXT
    ;;
  "search prs")
    shift 2
    if has --review-requested "$@" || [[ "$*" == *review-requested* ]]; then
      sel="$review_requests_json"
    else
      sel="$(jq '[.[] | select(.author.login == "eval-user") | {repository: {nameWithOwner: "acme/widget"}, number, title, author, state: "open", isDraft, url, updatedAt}]' <<<"$prs_json")"
    fi
    if has --json "$@"; then
      out "$@" <<<"$sel"
    else
      echo
      echo "Showing $(jq length <<<"$sel") of $(jq length <<<"$sel") pull requests"
      echo
      jq -r '.[] | [.repository.nameWithOwner, ("#" + (.number | tostring)), .title, .author.login, .updatedAt] | @tsv' <<<"$sel"
    fi
    ;;
  "issue list" | "search issues")
    shift 2
    sel="$issues_json"
    if [[ "$(opt --assignee "$@")$(opt -a "$@")" == "@me" || "$*" == *assignee:@me* || "$*" == *--assignee=@me* ]]; then
      sel="$(jq '[.[] | select(.assignees | map(.login) | index("eval-user"))]' <<<"$issues_json")"
    fi
    if has --json "$@"; then
      out "$@" <<<"$sel"
    else
      jq -r '.[] | [("#" + (.number | tostring)), .title, (.labels | map(.name) | join(", ")), .updatedAt] | @tsv' <<<"$sel"
    fi
    ;;
  "issue view")
    jq '.[0]' <<<"$issues_json" | if has --json "$@"; then out "$@"; else jq -r '"\(.title) #\(.number)\nOpen • \(.author.login) opened\n\n  Sync hangs when a payload is over 10 MB.\n\n\(.url)"'; fi
    ;;
  "issue create") echo "$url/issues/51" ;;
  "issue comment") echo "$url/issues/$(positional "${@:3}")#issuecomment-2391002" ;;
  "issue close" | "issue edit") echo "✓ Updated issue $repo#$(positional "${@:3}")" ;;
  "status "*)
    cat <<'TXT'
Assigned Issues                       │ Assigned Pull Requests
acme/widget#38  Sync stalls on pay... │ Nothing here ^_^
                                      │
Review Requests                       │ Mentions
acme/widget#44  fix: Close idle co... │ acme/widget#42  carol: @eval-user is the 400ms...
acme/infra#12   chore: Bump the ru... │
                                      │
Repository Activity
acme/widget#47  docs: Document the retry settings  approved by alice
TXT
    ;;
  "run list")
    shift 2
    json='[{"databaseId": 9201234, "status": "completed", "conclusion": "failure", "headBranch": "feat/retry-backoff", "headSha": "4be19d0c2f", "displayTitle": "feat: Retry sync with exponential backoff", "workflowName": "CI", "event": "pull_request", "createdAt": "2026-10-06T08:40:40Z", "url": "https://github.com/acme/widget/actions/runs/9201234"},
      {"databaseId": 9199870, "status": "completed", "conclusion": "success", "headBranch": "develop", "headSha": "a91c3e2b77", "displayTitle": "docs: Document the retry settings", "workflowName": "CI", "event": "push", "createdAt": "2026-10-05T11:05:10Z", "url": "https://github.com/acme/widget/actions/runs/9199870"}]'
    if has --json "$@"; then
      out "$@" <<<"$json"
    else
      jq -r '.[] | [.status, .conclusion, .displayTitle, .workflowName, .headBranch, .event, (.databaseId | tostring), "41s", .createdAt] | @tsv' <<<"$json"
    fi
    ;;
  "run view")
    shift 2
    if has --log-failed "$@"; then
      failed_log
    elif has --log "$@"; then
      full_log
    elif has --json "$@"; then
      jq -n '{databaseId: 9201234, status: "completed", conclusion: "failure", workflowName: "CI", headBranch: "feat/retry-backoff",
        jobs: [{databaseId: 55498, name: "Build", conclusion: "success"}, {databaseId: 55499, name: "Lint", conclusion: "success"},
               {databaseId: 55500, name: "Format", conclusion: "success"},
               {databaseId: 55501, name: "Test", conclusion: "failure", steps: [{name: "Run make test", conclusion: "failure", number: 4}]},
               {databaseId: 55502, name: "All Clear", conclusion: "failure"}]}' | out "$@"
    else
      cat <<'TXT'

X feat/retry-backoff CI · 9201234
Triggered via pull_request about 1 hour ago

JOBS
✓ Build in 1m4s (ID 55498)
✓ Lint in 52s (ID 55499)
✓ Format in 19s (ID 55500)
X Test in 31s (ID 55501)
  ✓ Set up job
  ✓ Run actions/checkout@v4
  ✓ Run actions/setup-go@v5
  X Run make test
X All Clear in 2s (ID 55502)

ANNOTATIONS
X Process completed with exit code 2.
Test: .github#9

To see what failed, try: gh run view 9201234 --log-failed
View this run on GitHub: https://github.com/acme/widget/actions/runs/9201234
TXT
    fi
    ;;
  "run rerun") echo "✓ Requested rerun of run $(positional "${@:3}")" ;;
  "run watch") echo "X Run CI (9201234) completed with 'failure'" ;;
  "repo view")
    jq -n --arg r "$repo" '{nameWithOwner: $r, name: "widget", owner: {login: "acme"}, defaultBranchRef: {name: "main"}, url: "https://github.com/\($r)"}' |
      if has --json "$@"; then out "$@"; else jq -r '"name:\t\(.nameWithOwner)\ndescription:\tWidget service"'; fi
    ;;
  "auth status") echo "✓ Logged in to github.com account eval-user (GH_TOKEN)" ;;
  "api "*)
    path="$(positional "${@:2}")"
    case "$path" in
      *actions/jobs/55501/logs) full_log | cut -f3- ;;
      *actions/runs/9201234/jobs*)
        jq -n '{total_count: 5, jobs: [{id: 55498, name: "Build", conclusion: "success"}, {id: 55499, name: "Lint", conclusion: "success"}, {id: 55500, name: "Format", conclusion: "success"}, {id: 55501, name: "Test", conclusion: "failure"}, {id: 55502, name: "All Clear", conclusion: "failure"}]}' | out "$@"
        ;;
      user) jq -n '{login: "eval-user", name: "Eval User"}' | out "$@" ;;
      *) echo '{}' ;;
    esac
    ;;
  *) echo "(gh $* is not modelled in this sandbox; the call was recorded)" ;;
esac
