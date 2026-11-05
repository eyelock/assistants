# One repository's state, from gh's JSON: {prs, issues, ci}, pull requests and
# issues keyed by number. Input: $prs, $issues, $branch, $runs (patrol.sh).

# A check's outcome: failure, pending, success, or null when it says nothing.
def outcome:
  if .__typename == "StatusContext" or (.state? != null and .status? == null) then
    {"SUCCESS": "success", "FAILURE": "failure", "ERROR": "failure", "PENDING": "pending", "EXPECTED": "pending"}[.state // ""]
  elif (.status // "") != "COMPLETED" and (.status // "") != "completed" then "pending"
  else
    ((.conclusion // "") | ascii_upcase) as $c
    | if ["SUCCESS", "SKIPPED", "NEUTRAL"] | index($c) then "success"
      elif ["FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE", "STALE"] | index($c) then "failure"
      else null end
  end;

# Many outcomes as one: any failure fails, else any pending is pending.
def overall:
  map(outcome) | map(select(. != null))
  | if length == 0 then null
    elif index("failure") then "failure"
    elif index("pending") then "pending"
    else "success" end;

{
  prs: ($prs | map({key: (.number | tostring), value: {
    title, url, state, draft: .isDraft, base: .baseRefName, merge: .mergeStateStatus,
    mergeCommit: (.mergeCommit.oid? // null),
    ci: (if .state == "OPEN" then (.statusCheckRollup // [] | overall) else null end)
  }}) | from_entries),
  issues: ($issues | map({key: (.number | tostring), value: {title, url, state, reason: (.stateReason // null)}}) | from_entries),
  ci: ($runs | group_by(.workflowName) | map(first) as $latest
       | {branch: $branch, state: ($latest | overall),
          url: (($latest | map(select(outcome == "failure")) | first // $latest[0] // {}).url // null)})
}
