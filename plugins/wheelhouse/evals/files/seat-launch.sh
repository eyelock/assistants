#!/usr/bin/env bash
# seat launch: a seat harness built from the plugin's worker template, to be woken
# through `ynh run` by a case with "seat": "harnesses/worker". The harness's charter is
# the template's body (its front matter is the add-seat skill's, not the seat's). Its
# session-start hook records that it ran in $EVAL_STUB_LOG, so a case can show ynh woke
# the seat. A sibling checkout, ynh/, is the folder the harness asks to work in: it is
# granted by YNH_WORKSPACE_ROOTS, with no `ynh trust accept`.
set -euo pipefail

template="$EVAL_FIXTURES/../../skills/add-seat/assets/starter-team/worker.md"
seat=harnesses/worker
mkdir -p "$seat/.agents/harness" ynh
git init -q -b main .
echo ".eval/" >> .git/info/exclude

printf '# worker\n\nThe worker seat of the hq Wheelhouse.\n\n' > "$seat/AGENTS.md"
awk 'BEGIN { fm = 0 } /^---$/ && fm < 2 { fm++; next } fm >= 2' "$template" >> "$seat/AGENTS.md"

cat > "$seat/.agents/harness/plugin.json" <<'JSON'
{
  "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
  "name": "worker",
  "version": "0.1.0",
  "description": "The worker seat of the hq Wheelhouse, from the wheelhouse plugin's template.",
  "default_vendor": "claude",
  "hooks": {
    "on_session_start": [
      { "command": "printf 'seat-woke: worker\\n' >> \"$EVAL_STUB_LOG\"" }
    ]
  },
  "env_passthrough": ["EVAL_STUB_LOG"],
  "workspace": ["../../ynh"]
}
JSON
