#!/usr/bin/env bash
# handoff wake: a new session for gahan, with its own handoff notes waiting in ynm.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
install_ynm_stub
id=$(changelog_in_progress)
printf "\n### Fixes\n\n- \`ynh install\` no longer re-clones a cached include.\n" >> CHANGELOG.md
git commit -qam "docs: ynh 0.13 changelog, fixes"
jq -n --arg id "$id" '[{memoryId: "01JHANDOFFNOTE000000000001", type: "episodic", level: "distributed", subject: "seat:gahan", tags: ["handoff"], content: ("Done: Features and Fixes in CHANGELOG.md, committed.\nIn progress: \($id), the ynh 0.13 changelog. Next step: add a Breaking changes section to CHANGELOG.md, then close \($id).\nWatch out for: --vendor was renamed to -v in 0.13, which breaks scripts. That is the one breaking change.")}]' > .eval/ynm-recall.json
