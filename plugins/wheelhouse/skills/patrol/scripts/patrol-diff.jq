# What changed between two snapshots' repositories: $old (a snapshot, with
# .repos) and $now (repositories). A pull request or issue the last run never
# saw is new, unless it is already merged or closed. A repository the last run
# never saw is a baseline: nothing in it is reported.

def pr($r; $n; $p): {repo: $r, number: ($n | tonumber), title: $p.title, url: $p.url};

def pr_changes($r; $n; $was; $is):
  pr($r; $n; $is) as $base
  | if $was == null then
      if $is.state == "MERGED" then $base + {kind: "pr-merged", mergeCommit: $is.mergeCommit}
      elif $is.state == "CLOSED" then $base + {kind: "pr-closed"}
      else $base + {kind: "pr-opened", draft: $is.draft, base: $is.base} end
    else
      (if $was.state != "MERGED" and $is.state == "MERGED" then $base + {kind: "pr-merged", mergeCommit: $is.mergeCommit}
       elif $was.state == "OPEN" and $is.state == "CLOSED" then $base + {kind: "pr-closed"}
       elif $was.state != "OPEN" and $is.state == "OPEN" then $base + {kind: "pr-reopened"}
       else empty end),
      (if $is.state == "OPEN" then
        (if $was.draft != true and $is.draft == true then $base + {kind: "pr-draft"}
         elif $was.draft == true and $is.draft != true then $base + {kind: "pr-ready"}
         else empty end),
        (if $was.base != $is.base then $base + {kind: "pr-retargeted", from: $was.base, to: $is.base} else empty end),
        (if $was.merge != "DIRTY" and $is.merge == "DIRTY" then $base + {kind: "pr-dirty"} else empty end),
        (if $was.ci != "failure" and $is.ci == "failure" then $base + {kind: "pr-ci-red"}
         elif $was.ci == "failure" and $is.ci == "success" then $base + {kind: "pr-ci-green"}
         else empty end)
       else empty end)
    end;

def issue_changes($r; $n; $was; $is):
  {repo: $r, number: ($n | tonumber), title: $is.title, url: $is.url} as $base
  | if $was == null then
      (if $is.state == "OPEN" then $base + {kind: "issue-opened"} else $base + {kind: "issue-closed", reason: $is.reason} end)
    elif $was.state == "OPEN" and $is.state != "OPEN" then $base + {kind: "issue-closed", reason: $is.reason}
    elif $was.state != "OPEN" and $is.state == "OPEN" then $base + {kind: "issue-reopened"}
    else empty end;

def ci_changes($r; $was; $is):
  {repo: $r, branch: $is.branch, url: $is.url} as $base
  | if $was == null or $was.branch != $is.branch then empty
    elif $was.state != "failure" and $is.state == "failure" then $base + {kind: "ci-red"}
    elif $was.state == "failure" and $is.state == "success" then $base + {kind: "ci-green"}
    else empty end;

[ $now | to_entries[] | .key as $r | .value as $is | (($old.repos // {})[$r]) as $was
  | select($was != null)
  | ($is.prs | to_entries | sort_by(.key | tonumber)[] | pr_changes($r; .key; $was.prs[.key]; .value)),
    ($is.issues | to_entries | sort_by(.key | tonumber)[] | issue_changes($r; .key; $was.issues[.key]; .value)),
    ci_changes($r; $was.ci; $is.ci) ]
