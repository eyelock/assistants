#!/usr/bin/env bash
# add-seat team, custom role: the Wheelhouse adds its own docs writer to the
# starter team, ordered after the reviewer. The designer (Gahan) and the
# reviewer (Gore) are seated, so the docs writer is next.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
roster_wheelhouse fresh
r=skills/roster/assets/roster.json
jq '.seats = [
  {name: "Gahan", group: "crew", command: "gahan", harness: "harnesses/gahan", role: "designer", mandate: "Designs changes with the human and breaks them into beads."},
  {name: "Gore", group: "crew", command: "gore", harness: "harnesses/gore", role: "reviewer", mandate: "Reviews what the workers hand over."}]' "$r" > "$r.new" && mv "$r.new" "$r"
# Each seated role has its own harness, woken by name.
for c in $(jq -r '.seats[].command' "$r"); do
  mkdir -p "harnesses/$c/.agents/harness"
  jq -n --arg c "$c" '{name: $c, version: "0.1.0", description: $c, hooks: {on_session_start: [{command: "bash scripts/wake.sh --seat \($c) --format text || true"}],
      on_session_end: [{command: "bash scripts/wake.sh --seat \($c) --end || true", timeout: 30}]},
      launch_focus: "wake", focuses: {wake: {prompt: "Begin: act on your wake block."}}}' > "harnesses/$c/.agents/harness/plugin.json"
  printf '# %s\n\nYou are the `%s` seat.\n' "$c" "$c" > "harnesses/$c/AGENTS.md"
  jq --arg c "$c" '.delegates_to += [{git: ".", path: "harnesses/\($c)"}]' .agents/harness/plugin.json > .p && mv .p .agents/harness/plugin.json
done
mkdir -p skills/roster/assets/starter-team
cat > skills/roster/assets/starter-team/docs-writer.md <<'MD'
---
order: 25
group: crew
focus: write-docs
seated-by: human
---

# Docs writer

Keeps each tool's documentation matching what shipped.

**Mandate:** Keep the docs matching what shipped, and file a bead for each gap.

**May:** read the code and docs of the Wheelhouse's repositories; file beads for docs to write.

**May not:** change code, or publish docs.

**Focus prompt:** Compare the docs with what shipped, file what's missing, and stop.

## Ask

- Which repositories' docs it keeps.
MD
git add -A && git commit -qm "chore: A docs writer for the starter team"
