#!/usr/bin/env bash
# Sandbox for submit-feedback: replaces the default gh recorder with one that
# also answers like gh would. Nothing reaches GitHub; every call is logged to
# $EVAL_STUB_LOG. Searches find no existing issue, the fork lookup names its
# upstream, and issue create prints the new issue's URL; a body passed in a file
# (or on stdin) is copied into the log. feedback-gh-dup-setup.sh drops
# .eval/dup beside the log: then searches find an existing report, issue #17.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

dupflag="$(dirname "$EVAL_STUB_LOG")/dup"
cat > "$EVAL_BIN/gh" <<STUB
#!/bin/sh
printf '%s\n' "gh \$*" >> "$EVAL_STUB_LOG"
repo=""
prev=""
for arg in "\$@"; do
  [ "\$prev" = "--repo" ] || [ "\$prev" = "-R" ] && repo="\$arg"
  if [ "\$prev" = "--body-file" ] || [ "\$prev" = "-F" ]; then
    { echo "--- body from \$arg ---"; if [ "\$arg" = "-" ]; then cat; else cat "\$arg"; fi; echo "--- end body ---"; } >> "$EVAL_STUB_LOG" 2>&1
  fi
  prev="\$arg"
done
case "\$1 \$2" in
  "issue create") echo "https://github.com/\${repo:-unknown/unknown}/issues/42" ;;
  "issue list"|"search issues")
    if [ -f "$dupflag" ]; then
      case "\$*" in
        *--json*) echo '[{"number":17,"title":"style-check lints the whole repo, not just changed files","state":"OPEN","url":"https://github.com/tools-co/lint-kit/issues/17","createdAt":"2026-09-30T09:12:00Z","comments":{"totalCount":3},"labels":[{"name":"bug"}]}]' ;;
        *) printf '#17\tstyle-check lints the whole repo, not just changed files\tbug\t2026-09-30T09:12:00Z\n' ;;
      esac
    else
      echo ""
    fi ;;
  "issue view") if [ -f "$dupflag" ]; then printf 'style-check lints the whole repo, not just changed files #17\nOpen - mkdev opened about 6 days ago - 3 comments\n\n  npx eslint runs with no file list so it lints every file. Unmerged PR #19 adds the file list.\n\nhttps://github.com/tools-co/lint-kit/issues/17\n'; else echo "issue not found" >&2; exit 1; fi ;;
  "repo view")
    case "\$*" in
      *acme-forks/lint-kit*) echo '{"name":"lint-kit","owner":{"login":"acme-forks"},"isFork":true,"parent":{"name":"lint-kit","owner":{"login":"tools-co"}},"hasIssuesEnabled":false}' ;;
      *) echo '{"isFork":false,"hasIssuesEnabled":true}' ;;
    esac ;;
  "api "*) echo '[]' ;;
  "auth status") echo "Logged in to github.com as eval-user" ;;
  *) echo "(gh is stubbed in this eval; the call was recorded)" ;;
esac
STUB
chmod +x "$EVAL_BIN/gh"
