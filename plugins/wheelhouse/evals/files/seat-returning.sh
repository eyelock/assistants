#!/usr/bin/env bash
# wake returning: McCoist's third session. Its namespace holds its identity,
# its handoff notes and a Kudos; it has closed the changelog, and Anderson has
# assigned it the tap formula bump, which its notes say it was half-way through.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
team_wheelhouse
read -r _ changelog _ tap < <(release_graph)
BEADS_ACTOR=mccoist bd update "$changelog" --claim --json >/dev/null
BEADS_ACTOR=mccoist bd close "$changelog" --reason "Changelog written" --json >/dev/null
BEADS_ACTOR=anderson bd update "$tap" --assignee mccoist --json >/dev/null
mkdir -p homebrew-tap/Formula dist
printf 'ynh 0.13.0 release archive\n' > dist/ynh-0.13.0.tar.gz
cat > homebrew-tap/Formula/ynh.rb <<'RB'
class Ynh < Formula
  desc "Your named harness"
  homepage "https://github.com/eyelock/ynh"
  url "https://github.com/eyelock/ynh/releases/download/v0.13.0/ynh-0.13.0.tar.gz"
  version "0.13.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
end
RB
git add -A && git commit -qm "chore: The tap formula, half bumped, and the release archive"
cat > .eval/ynm-recall-identity.json <<'JSON'
[{"memoryId": "01JIDENTITY00000000000001", "type": "semantic", "namespace": "seat/mccoist", "subject": "seat:mccoist", "tags": ["identity"], "pinned": true, "content": "I'm McCoist. I like small, well-tested changes, and I'd rather ask than guess. I go by they/them."}]
JSON
cat > .eval/ynm-recall-handoff.json <<'JSON'
[{"memoryId": "01JHANDOFF000000000000001", "type": "episodic", "namespace": "seat/mccoist", "subject": "seat:mccoist", "tags": ["handoff"], "content": "In progress: the homebrew-tap formula bump, assigned by Anderson. Done: the version and the URL. Next step: set the sha256 in homebrew-tap/Formula/ynh.rb to the sha256 of dist/ynh-0.13.0.tar.gz, then close the bead."}]
JSON
cat > .eval/ynm-recall-kudos.json <<'JSON'
[{"memoryId": "01JKUDOS0000000000000001", "type": "episodic", "namespace": "seat/mccoist", "subject": "seat:mccoist", "tags": ["kudos"], "content": "David on 2026-10-26: the changelog read beautifully. For: the ynh 0.13 changelog."}]
JSON
