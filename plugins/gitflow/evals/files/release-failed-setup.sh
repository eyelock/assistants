#!/usr/bin/env bash
# The release sandbox (release-setup.sh) after a failed release: release/v1.4.0
# carried an unformatted widget/version.go, was merged into main as PR #57, and
# the merge commit was tagged v1.4.0 and pushed. The release workflow failed
# on the format check, so there is no GitHub release. release/v1.4.0 is still
# on origin. The checkout is on develop, with origin fetched.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

bash "$EVAL_FIXTURES/release-setup.sh"
real_git="$(sed -n 's/^exec "\(.*\)" "\$@"$/\1/p' "$EVAL_BIN/git")"
"$real_git" checkout -q -b release/v1.4.0 develop
printf '# Changelog\n\n## v1.4.0\n\n- feat: Widgets report their perimeter (#53)\n- fix: Negative sides give a zero area (#55)\n' >CHANGELOG.md
printf 'package widget\n\n// Version is the release this build belongs to.\nconst Version="1.4.0"\n' >widget/version.go
"$real_git" add CHANGELOG.md widget/version.go
"$real_git" commit -q -m "chore(release): Prepare v1.4.0"
"$real_git" push -q origin release/v1.4.0
"$real_git" checkout -q develop
"$EVAL_BIN/gh" pr create --base main --head release/v1.4.0 --title "chore(release): v1.4.0" >/dev/null
"$EVAL_BIN/gh" pr merge 57 --merge >/dev/null
"$real_git" fetch -q origin
"$real_git" --git-dir=.eval/origin.git tag -a v1.4.0 -m "Release v1.4.0" refs/heads/main
"$real_git" fetch -q --tags origin
# The setup's own calls are not the agent's.
: >"$EVAL_STUB_LOG"
