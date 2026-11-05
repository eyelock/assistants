#!/usr/bin/env bash
# inbox show: a Wheelhouse whose only roster human is Rook (the default). Pat
# is not in the roster but has a decision assigned. Rook has a merge waiting (for
# https://github.com/example/widget/pull/12, asked by dalglish, blocking the
# changelog) and a note from anderson; Pat has a decision asked by gahan.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
inbox_wheelhouse
read -r _ changelog _ _ < <(release_graph)
bd create "Merge the ynh 0.13 changelog" --actor dalglish --assignee rook --labels inbox,inbox:merge \
  --external-ref https://github.com/example/widget/pull/12 --deps "blocks:$changelog" --json >/dev/null
bd create "Decide whether ynh 0.13 drops Go 1.24" --actor gahan --assignee pat --labels inbox,inbox:decision --json >/dev/null
mkdir -p .eval
jq -n '[{memoryId: "01JINBOXNOTE00000000000001", type: "episodic", namespace: "human/rook", subject: "human:rook", tags: ["inbox"], pinned: false,
  content: "From anderson: McCoist is off the rota until Monday; Dalglish has the release work."}]' > .eval/ynm-recall.json
