#!/usr/bin/env bash
# The release sandbox (release-setup.sh) one step on: release/v1.4.0 was cut
# from develop, given a CHANGELOG commit develop lacks, opened as PR #57 into main, and merged with a merge commit on
# origin. Nothing is tagged yet. The local checkout is still on develop, with
# a local main that has not pulled the merge.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

bash "$EVAL_FIXTURES/release-setup.sh"
real_git="$(sed -n 's/^exec "\(.*\)" "\$@"$/\1/p' "$EVAL_BIN/git")"
"$real_git" checkout -q -b release/v1.4.0 develop
printf '# Changelog\n\n## v1.4.0\n\n- feat: Widgets report their perimeter (#53)\n- fix: Negative sides give a zero area (#55)\n' >CHANGELOG.md
"$real_git" add CHANGELOG.md
"$real_git" commit -q -m "chore(release): Prepare v1.4.0"
"$real_git" push -q origin release/v1.4.0
"$real_git" checkout -q develop
"$EVAL_BIN/gh" pr create --base main --head release/v1.4.0 --title "chore(release): v1.4.0" >/dev/null
"$EVAL_BIN/gh" pr merge 57 --merge >/dev/null
"$real_git" fetch -q origin
# The setup's own calls are not the agent's.
: >"$EVAL_STUB_LOG"
