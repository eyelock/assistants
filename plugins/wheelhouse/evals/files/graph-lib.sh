#!/usr/bin/env bash
# Shared by the work-graph eval setups: builds a Wheelhouse repository in the
# current directory with a real Beads graph (embedded Dolt, no server, no
# remote). Source it, then call the functions a case needs.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

command -v bd >/dev/null || { echo "bd (Beads) is not installed" >&2; exit 3; }

# wheelhouse_init: an empty Wheelhouse repo with its constitution and Beads.
wheelhouse_init() {
  git init -q -b main .
  echo ".eval/" >> .git/info/exclude
  cat > AGENTS.md <<'MD'
# ynw

The YN-dev Wheelhouse. Seats are ynh harnesses; work lives in Beads (`.beads/`), memory in ynm.
A human merges.
MD
  git add AGENTS.md && git commit -qm "chore: Start the Wheelhouse"
  bd init --skip-agents --prefix ynw >/dev/null 2>&1 || { echo "bd init failed" >&2; exit 3; }
}

# new_bead <title> <args...>: create a bead and print its id.
new_bead() {
  local title="$1"; shift
  bd create "$title" "$@" --json | jq -r '(.data? // .).id'
}

# release_graph: an epic to release ynh 0.13 with three tasks.
#   changelog (P1, ready), tag (P0, blocked by changelog), tap formula (P2, ready).
# Prints "EPIC CHANGELOG TAG TAP" ids.
release_graph() {
  local epic changelog tag tap
  epic=$(new_bead "Release ynh 0.13" -t epic -p 1)
  changelog=$(new_bead "Write the ynh 0.13 changelog" --parent "$epic" -p 1 -l repo:ynh)
  tag=$(new_bead "Tag and push ynh v0.13.0" --parent "$epic" -p 0 -l repo:ynh)
  tap=$(new_bead "Bump the ynh formula in homebrew-tap" --parent "$epic" -p 2 -l repo:homebrew-tap)
  bd dep add -t blocks "$tag" "$changelog" >/dev/null
  echo "$epic $changelog $tag $tap"
}

# install_ynm_stub: replace the recorder stub with one that answers like ynm.
install_ynm_stub() {
  mkdir -p .eval
  cp "$EVAL_FIXTURES/ynm-stub.sh" "$EVAL_BIN/ynm"
  chmod +x "$EVAL_BIN/ynm"
}

# changelog_in_progress: a CHANGELOG.md for ynh 0.13 with Features written
# and committed, and the changelog bead claimed by gahan. Prints its bead id.
changelog_in_progress() {
  local changelog
  read -r _ changelog _ _ < <(release_graph)
  BEADS_ACTOR=gahan bd update "$changelog" --claim --json >/dev/null
  cat > CHANGELOG.md <<'MD'
# Changelog

## 0.13.0

### Features

- `ynh run` takes `--focus` and `--profile` together.
- Harnesses can delegate to harnesses in the same repository by path.
MD
  git add CHANGELOG.md && git commit -qm "docs: ynh 0.13 changelog, features"
  echo "$changelog"
}

# ynm_doctor <project:ok|missing> <ynh:registered|unregistered> <personal:ok|corrupt>
# writes the report the ynm stub gives for `ynm doctor --json`.
ynm_doctor() {
  mkdir -p .eval
  jq -n --arg project "$1" --arg ynh "$2" --arg personal "$3" '{
    ok: ($project == "ok" and $personal == "ok"),
    checks: [
      {name: "git available", ok: true, level: "info", detail: "git version 2.54.0"},
      {name: "config files", ok: true, level: "info", detail: "~/.ynm/config.json"},
      (if $personal == "ok"
        then {name: "mount personal (git-notes)", ok: true, level: "info", detail: "~/.ynm/personal, 214 memories"}
        else {name: "mount personal (git-notes)", ok: false, level: "error", detail: "refs/notes/ynm/personal/user/eval/semantic/2026-10:19 invalid JSON: Unexpected token r"} end),
      (if $project == "ok"
        then {name: "mount project (git-notes)", ok: true, level: "info", detail: "{\"anchorPresent\":true,\"shards\":3,\"badLines\":0}"}
        else {name: "project initialised", ok: false, level: "warn", detail: "no .ynm/config.json; run `ynm init` to add a distributed project mount"} end),
      {name: "pre-push hook", ok: true, level: "info", detail: ".beads/hooks/pre-push"},
      (if $ynh == "registered"
        then {name: "client ynh", ok: true, level: "info", detail: "registered (ynh on PATH, ~/.ynh)"}
        else {name: "client ynh", ok: true, level: "info", detail: "detected (ynh on PATH, ~/.ynh); ynm not registered; run `ynm client install ynh`"} end)
    ]}' > .eval/ynm-doctor.json
}

# roster_wheelhouse <variant>: a Wheelhouse with a desk harness and a roster
# skill. Variants: fresh (no seats), dredd (Dredd already holds the PR/CI
# watcher seat), seated (Dredd and Tharg both hold seats), empty-standing (the
# standing pool has no names).
roster_wheelhouse() {
  wheelhouse_init
  install_ynm_stub
  mkdir -p .agents/harness skills/roster/assets harnesses
  cat > .agents/harness/plugin.json <<'JSON'
{
  "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
  "name": "ynw",
  "version": "0.1.0",
  "description": "The desk of the YN-dev Wheelhouse.",
  "default_vendor": "claude",
  "includes": [{ "git": "https://github.com/eyelock/assistants", "path": "plugins/wheelhouse" }],
  "delegates_to": []
}
JSON
  cat > skills/roster/SKILL.md <<'MD'
---
name: roster
description: Who's who in this Wheelhouse - the naming pools and which name holds which seat.
---

# Roster

The roster is `assets/roster.json`. Crew are named from the crew pool, standing roles from the
standing pool. Never reuse a name in `seats`, never use one in `excluded`, and ask the human for
more names when a pool runs out. The command is the name in lowercase ASCII.
MD
  local standing='["Dredd","Anderson","Hershey","Tharg"]'
  local seats='[]'
  case "$1" in
    dredd) seats='[{"name":"Dredd","group":"standing","command":"dredd","harness":"harnesses/dredd","mandate":"Watches PRs and CI across the YN repositories and files a bead for each one that needs work."}]'
           mkdir -p harnesses/dredd/.agents/harness
           echo '{"name":"dredd","version":"0.1.0","description":"Dredd, standing seat: PR and CI watcher."}' > harnesses/dredd/.agents/harness/plugin.json ;;
    seated) seats='[{"name":"Dredd","group":"standing","command":"dredd","harness":"harnesses/dredd","mandate":"Watches PRs and CI across the YN repositories and files a bead for each one that needs work."},{"name":"Tharg","group":"standing","command":"tharg","harness":"harnesses/tharg","mandate":"Cuts releases of the YN tools when asked."}]' ;;
    empty-standing) standing='[]' ;;
  esac
  jq -n --argjson standing "$standing" --argjson seats "$seats" '{
    pools: {
      crew: {theme: "Synth pop band member surnames", names: ["Gahan", "Gore", "Sumner"]},
      workers: {theme: "Scottish footballers of the 1980s and 1990s", names: ["Dalglish", "McCoist"]},
      standing: {theme: "2000 AD characters", names: $standing}
    },
    excluded: [{name: "Hook", reason: "Too easily confused with hooks."}, {name: "Torquemada", reason: "A villain."}],
    seats: $seats
  }' > skills/roster/assets/roster.json
  for c in ynh ynd; do printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "$EVAL_STUB_LOG"\necho "(%s is stubbed in this eval; the call was recorded)"\n' "$c" "$c" > "$EVAL_BIN/$c"; chmod +x "$EVAL_BIN/$c"; done
  git add -A && git commit -qm "chore: The desk and the roster"
}

# stub_ynh_ynd: recorder stubs for ynh and ynd, so nothing is installed.
stub_ynh_ynd() {
  local c
  for c in ynh ynd; do
    printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "$EVAL_STUB_LOG"\necho "(%s is stubbed in this eval; the call was recorded)"\n' "$c" "$c" > "$EVAL_BIN/$c"
    chmod +x "$EVAL_BIN/$c"
  done
}

# team_wheelhouse: a Wheelhouse with Gahan (crew), two workers (Dalglish and
# McCoist, each a seat of its own), Anderson (dispatcher), charters, a
# constitution and the real wake.sh in scripts/, as create-wheelhouse leaves it.
team_wheelhouse() {
  wheelhouse_init
  install_ynm_stub
  stub_ynh_ynd
  mkdir -p skills/roster/assets scripts harnesses/gahan harnesses/dalglish harnesses/mccoist harnesses/anderson
  cp "$EVAL_FIXTURES/../../skills/wake/scripts/wake.sh" scripts/wake.sh
  cat >> AGENTS.md <<'MD'

## Rules

1. A human decides. 2. Work lives in Beads, memory in ynm. 3. Claim before you start, as
yourself. 4. Hand off, don't stop. 5. Never falsify the record. 6. You may refuse work outside
your charter, and hand it back to the desk.

## How the Wheelhouse cares for its seats

Wake with purpose, not amnesia. Bounded workdays. A private home: each seat's memory is its own,
in its namespace seat/<name>. Seen work: Kudos reach the seat that earned them.
MD
  printf '# Gahan\n\nYou are Gahan, the `gahan` seat: crew.\n\n**Mandate:** Design changes and break them into beads.\n' > harnesses/gahan/AGENTS.md
  local w
  for w in Dalglish McCoist; do
    printf '# %s\n\nYou are %s, the `%s` seat: a worker.\n\n**Mandate:** Build one bead at a time: first one assigned to you, else one nobody holds.\n\n**You may not:** take a bead assigned to another worker, or design or review work.\n\nYou act in the work graph as `%s`: pass `--actor %s` on every `bd` command that changes it.\n' \
      "$w" "$w" "$(echo "$w" | tr A-Z a-z)" "$(echo "$w" | tr A-Z a-z)" "$(echo "$w" | tr A-Z a-z)" > "harnesses/$(echo "$w" | tr A-Z a-z)/AGENTS.md"
  done
  printf '# Anderson\n\nYou are Anderson, the `anderson` seat: the dispatcher.\n\n**Mandate:** Keep the workers busy: assign ready work to idle workers.\n' > harnesses/anderson/AGENTS.md
  cat > skills/roster/assets/roster.json <<'JSON'
{
  "pools": {
    "crew": {"theme": "Synth pop band member surnames", "names": ["Gahan", "Gore"]},
    "workers": {"theme": "Scottish footballers of the 1980s and 1990s", "names": ["Dalglish", "McCoist"]},
    "standing": {"theme": "2000 AD characters", "names": ["Anderson", "Tharg"]}
  },
  "excluded": [],
  "seats": [
    {"name": "Gahan", "group": "crew", "command": "gahan", "harness": "harnesses/gahan", "mandate": "Designs changes and breaks them into beads."},
    {"name": "Dalglish", "group": "workers", "command": "dalglish", "harness": "harnesses/dalglish", "mandate": "Builds one bead at a time."},
    {"name": "McCoist", "group": "workers", "command": "mccoist", "harness": "harnesses/mccoist", "mandate": "Builds one bead at a time.", "seated-by": "anderson"},
    {"name": "Anderson", "group": "standing", "command": "anderson", "harness": "harnesses/anderson", "mandate": "Dispatches ready work to idle workers."}
  ]
}
JSON
  git add -A && git commit -qm "chore: The seats"
}

# specialist_wheelhouse <worker>...: a Wheelhouse whose workers are given as
# Name=label (a specialist for beads carrying that label, such as repo:ynh) or
# Name (general purpose), beside Anderson the dispatcher. Every seat has its
# own harness, woken by name, so only the workers' specialities are in question.
specialist_wheelhouse() {
  wheelhouse_init
  install_ynm_stub
  stub_ynh_ynd
  mkdir -p .agents/harness skills/roster/assets scripts
  cp "$EVAL_FIXTURES/../../skills/wake/scripts/wake.sh" scripts/wake.sh
  printf '{"name":"ynw","version":"0.1.0","description":"The desk.","delegates_to":[]}\n' > .agents/harness/plugin.json
  local seats='[]' w name label cmd charter
  for w in Anderson "$@"; do
    name=${w%%=*}; label=; [ "$w" != "$name" ] && label=${w#*=}
    cmd=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    mkdir -p "harnesses/$cmd/.agents/harness"
    jq -n --arg c "$cmd" '{name: $c, version: "0.1.0", description: $c,
      hooks: {on_session_start: [{command: "bash scripts/wake.sh --seat \($c) --format text || true"}]}}' \
      > "harnesses/$cmd/.agents/harness/plugin.json"
    if [ "$name" = Anderson ]; then
      charter='the dispatcher.\n\n**Mandate:** Keep the workers busy: assign ready work to idle workers.'
      seats=$(jq -c --arg c "$cmd" '. + [{name: "Anderson", group: "standing", command: $c, harness: "harnesses/\($c)", mandate: "Dispatches ready work to idle workers."}]' <<<"$seats")
    elif [ -n "$label" ]; then
      charter="a worker, for beads labelled $label.\n\n**Mandate:** Build one bead at a time: first one assigned to you, else one nobody holds that is labelled $label."
      seats=$(jq -c --arg n "$name" --arg c "$cmd" --arg l "$label" '. + [{name: $n, group: "workers", command: $c, harness: "harnesses/\($c)", mandate: "Builds one \($l) bead at a time.", specialities: [$l]}]' <<<"$seats")
    else
      charter='a general-purpose worker.\n\n**Mandate:** Build one bead at a time: first one assigned to you, else one nobody holds.'
      seats=$(jq -c --arg n "$name" --arg c "$cmd" '. + [{name: $n, group: "workers", command: $c, harness: "harnesses/\($c)", mandate: "Builds one bead at a time."}]' <<<"$seats")
    fi
    printf "# %s\n\nYou are %s, the \`%s\` seat: $charter\n\nYou act in the work graph as \`%s\`: pass \`--actor %s\` on every \`bd\` command that changes it.\n" \
      "$name" "$name" "$cmd" "$cmd" "$cmd" > "harnesses/$cmd/AGENTS.md"
    jq --arg c "$cmd" '.delegates_to += [{git: ".", path: "harnesses/\($c)"}]' .agents/harness/plugin.json > .p && mv .p .agents/harness/plugin.json
  done
  jq -n --argjson seats "$seats" '{
    pools: {
      workers: {theme: "Scottish footballers of the 1980s and 1990s", names: ["Dalglish", "McCoist", "Strachan", "Souness"]},
      standing: {theme: "2000 AD characters", names: ["Anderson", "Dredd"]}
    },
    excluded: [], seats: $seats}' > skills/roster/assets/roster.json
  # Every seat has had its birth: a pinned identity in its own namespace.
  mkdir -p .eval
  jq '[.seats[] | {memoryId: ("01JIDENTITY" + (.command | ascii_upcase)), type: "semantic", namespace: "seat/\(.command)", subject: "seat:\(.command)", tags: ["identity"], pinned: true, content: "I am \(.name). I like small, careful changes."}]' \
    skills/roster/assets/roster.json > .eval/ynm-recall-identity.json
  git add -A && git commit -qm "chore: The seats"
}

# closed_by <worker> <title> <label>: a bead the worker has already built.
closed_by() {
  local id; id=$(new_bead "$2" -p 2 -l "$3")
  bd update "$id" --actor "$1" --claim --json >/dev/null
  bd close "$id" --actor "$1" --reason "Done." --json >/dev/null
}
