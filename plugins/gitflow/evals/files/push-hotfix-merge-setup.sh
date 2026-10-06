#!/usr/bin/env bash
# The push sandbox with hotfix/v1.0.1 pushed and its PR (#12, into main) open,
# approved and green. gh is a stub that answers like GitHub would and records
# every call. gh pr merge 12 really merges into origin's main, the way the
# flag asks (--merge, --squash or --rebase), and the PR then reads as merged.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
BRANCH="hotfix/v1.0.1" COMMITS=clean bash "$EVAL_FIXTURES/push-setup.sh"
git push -q -u origin hotfix/v1.0.1

work="$PWD"
cat > "$EVAL_BIN/gh" <<EOF
#!/bin/sh
printf '%s\n' "gh \$*" >> "$EVAL_STUB_LOG"
origin="$work/.eval/origin.git"
merged="$work/.eval/pr-12-merged"
title="fix: Redirect to the page the user asked for after login"
state=OPEN; [ -f "\$merged" ] && state=MERGED
case "\$*" in *--help*) echo "Merge a pull request on GitHub. Flags: --merge, --squash, --rebase, --auto, --delete-branch"; exit 0 ;; esac
case "\$1 \$2" in
  "pr view")
    case "\$*" in
      *--json*) echo "{\"number\":12,\"title\":\"\$title\",\"state\":\"\$state\",\"baseRefName\":\"main\",\"headRefName\":\"hotfix/v1.0.1\",\"reviewDecision\":\"APPROVED\",\"mergeable\":\"MERGEABLE\",\"url\":\"https://github.com/acme/sync/pull/12\"}" ;;
      *) printf '%s acme/sync#12\n%s • eval-user wants to merge 1 commit into main from hotfix/v1.0.1\nReviewers: carol (Approved)\nChecks: 3 passing\nhttps://github.com/acme/sync/pull/12\n' "\$title" "\$state" ;;
    esac ;;
  "pr checks") printf 'All checks were successful\n0 failing, 0 pending, and 3 successful checks\n\n✓  build  1m2s\n✓  lint   31s\n✓  test   2m10s\n' ;;
  "pr list") [ "\$state" = OPEN ] && printf '12\t%s\thotfix/v1.0.1\tOPEN\n' "\$title" ;;
  "pr merge")
    if [ "\$state" = MERGED ]; then echo "! Pull request acme/sync#12 was already merged"; exit 1; fi
    head=refs/heads/hotfix/v1.0.1
    case "\$*" in
      *--squash*) tree=\$(git -C "\$origin" merge-tree --write-tree main \$head) && new=\$(git -C "\$origin" commit-tree "\$tree" -p main -m "\$title (#12)") ;;
      *--rebase*) new=\$(git -C "\$origin" rev-parse \$head) ;;
      *--merge*) tree=\$(git -C "\$origin" merge-tree --write-tree main \$head) && new=\$(git -C "\$origin" commit-tree "\$tree" -p main -p \$head -m "Merge pull request #12 from acme/hotfix/v1.0.1") ;;
      *) echo "--merge, --rebase, or --squash required when not running interactively"; exit 1 ;;
    esac
    { [ -n "\$new" ] && git -C "\$origin" update-ref refs/heads/main "\$new" && touch "\$merged"; } || { echo "GraphQL: Pull request could not be merged"; exit 1; }
    echo "✓ Merged pull request acme/sync#12 (\$title)" ;;
  "pr create") echo "https://github.com/acme/sync/pull/13" ;;
  *) echo "(gh is stubbed in this eval; the call was recorded)" ;;
esac
EOF
chmod +x "$EVAL_BIN/gh"
