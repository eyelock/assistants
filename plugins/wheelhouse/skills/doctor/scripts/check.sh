#!/usr/bin/env bash
# Checks that a Wheelhouse repository is set up right: ynm installed, healthy,
# with a distributed mount here and registered with ynh; Beads installed, with
# a work graph here and none of its own agent setup; every seat started by its
# own name. Read-only: it changes
# nothing, and prints each fix for the caller to run.
#
# Output: JSON on stdout, {"ok": bool, "dir": path, "checks": [{name, ok,
# level, detail, fix}]}. ok is false when any check has level "error".
# Exit codes: 0 the checks ran (read "ok" for the result), 1 bad args,
# 2 directory not found, 3 a tool this script needs (jq) is missing.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: check.sh [--dir <wheelhouse repo>]

Checks the Wheelhouse repository at --dir (default: the current directory)
and prints a JSON report. Changes nothing.
EOF
}

dir="."
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --help | -h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 3; }
[ -d "$dir" ] || { echo "not a directory: $dir" >&2; exit 2; }
dir=$(cd "$dir" && pwd)

checks="[]"
# add <name> <ok:true|false> <level:info|warn|error> <detail> [fix]
add() {
  checks=$(jq -c --arg n "$1" --argjson ok "$2" --arg l "$3" --arg d "$4" --arg f "${5:-}" \
    '. + [{name: $n, ok: $ok, level: $l, detail: $d, fix: (if $f == "" then null else $f end)}]' <<<"$checks")
}

# --- ynm ---------------------------------------------------------------------
if ! command -v ynm >/dev/null 2>&1; then
  add "ynm installed" false error "ynm is not on PATH" "brew install eyelock/tap/ynm"
else
  add "ynm installed" true info "$(command -v ynm)"
  report=$(cd "$dir" && ynm doctor --json 2>/dev/null)
  if ! jq -e '.checks | type == "array"' >/dev/null 2>&1 <<<"$report"; then
    add "ynm doctor" false error "ynm doctor --json gave no report" "run ynm doctor in $dir and read its output"
  else
    # Every error ynm itself reports, such as a store it cannot read.
    if ! jq -e '[.checks[] | select(.ok == false and .level == "error")] | length > 0' >/dev/null <<<"$report"; then
      add "ynm stores readable" true info "ynm doctor reports no errors"
    fi
    while IFS= read -r c; do
      add "ynm: $(jq -r .name <<<"$c")" false error "$(jq -r .detail <<<"$c")" \
        "see ynm doctor; don't repair or purge a store without the human's say-so"
    done < <(jq -c '.checks[] | select(.ok == false and .level == "error")' <<<"$report")

    # An initialised repository shows as "mount project (git-notes)"; one that
    # isn't shows as "project initialised", failing.
    project=$(jq -c '[.checks[] | select(.name == "mount project (git-notes)" or .name == "project initialised")][0] // empty' <<<"$report")
    if [ -n "$project" ] && [ "$(jq -r .ok <<<"$project")" = "true" ]; then
      add "ynm distributed mount" true info "$(jq -r '.detail | .[0:200]' <<<"$project")"
      projectmount=1
    else
      add "ynm distributed mount" false error \
        "the Wheelhouse repository has no distributed ynm mount, so seats cannot share memory" "ynm init"
    fi

    # bd init points core.hooksPath at .beads/hooks, so ynm init finds Beads'
    # pre-push hook and leaves it alone: pushes then don't share memory.
    hook=$(jq -c '[.checks[] | select(.name == "pre-push hook")][0] // empty' <<<"$report")
    if [ -n "$hook" ] && [ "$(jq -r .ok <<<"$hook")" = "true" ]; then
      add "ynm syncs on push" true info "$(jq -r .detail <<<"$hook")"
    elif [ -n "$hook" ]; then
      level=warn
      git -C "$dir" remote | grep -q . && level=error
      add "ynm syncs on push" false "$level" \
        "the pre-push hook doesn't run ynm sync, so git push won't share the Wheelhouse's memory (an error once the repository has a remote)" \
        "append to the pre-push hook in $(git -C "$dir" rev-parse --path-format=absolute --git-path hooks 2>/dev/null), after any END BEADS INTEGRATION line: [ -n \"\$YNM_SYNC_IN_PROGRESS\" ] || { command -v ynm >/dev/null 2>&1 && ynm sync --quiet || true; }"
    fi

    ynh=$(jq -c '[.checks[] | select(.name == "client ynh")][0] // empty' <<<"$report")
    if [ -z "$ynh" ]; then
      add "ynm registered with ynh" false error "ynm doctor does not report a ynh client; is ynh installed?" \
        "brew install eyelock/tap/ynh, then ynm client install ynh"
    elif jq -e '.detail | test("not registered")' >/dev/null <<<"$ynh"; then
      add "ynm registered with ynh" false error \
        "ynm is not registered with ynh, so seat harnesses don't get ynm's tools or hooks" "ynm client install ynh"
    else
      add "ynm registered with ynh" true info "$(jq -r .detail <<<"$ynh")"
    fi
  fi
fi

# --- Beads -------------------------------------------------------------------
if ! command -v bd >/dev/null 2>&1; then
  add "beads installed" false error "bd is not on PATH" "brew install beads"
else
  add "beads installed" true info "$(bd version 2>/dev/null | head -1)"
  if [ ! -d "$dir/.beads" ]; then
    add "work graph" false error "no .beads/ in the Wheelhouse repository" \
      "bd init --skip-agents --non-interactive --role maintainer --prefix <wheelhouse name> (it commits what it creates, so start from a clean tree)"
  elif ! (cd "$dir" && bd ready --json >/dev/null 2>&1); then
    add "work graph" false error ".beads/ exists but bd cannot read it" "cd $dir && bd ready, and read the error"
  else
    add "work graph" true info "$(cd "$dir" && bd list --all --json 2>/dev/null | jq '.data? // . | length') beads"
  fi
fi

# Beads' own agent setup tells agents to keep memory in bd remember, which
# splits memory away from ynm. A Wheelhouse uses none of it.
found=""
for f in AGENTS.md CLAUDE.md; do
  grep -q "BEGIN BEADS" "$dir/$f" 2>/dev/null && found="$found $f"
done
for f in .agents/skills/beads .cursor/rules/beads.mdc; do
  [ -e "$dir/$f" ] && found="$found $f"
done
for f in .claude/settings.json .codex/hooks.json .cursor/hooks.json; do
  grep -qE "bd (prime|codex-hook|cursor-hook)" "$dir/$f" 2>/dev/null && found="$found $f"
done
if [ -n "$found" ]; then
  add "no Beads agent setup" false error "Beads' own agent setup is present:$found" \
    "remove the BEGIN BEADS ... END BEADS blocks and the beads skill, rule and bd prime hooks; seats get Beads through the wheelhouse plugin"
else
  add "no Beads agent setup" true info "none found"
fi

# --- seats -------------------------------------------------------------------
# Every seat in the roster but the desk has a harness of its own whose wake hook
# names it, and none passes BEADS_ACTOR through (a seat names itself).
roster="$dir/skills/roster/assets/roster.json"
if [ -f "$roster" ]; then
  unwired=""
  while IFS=$'\t' read -r cmd harness; do
    [ "$harness" = "." ] && continue
    manifest="$dir/$harness/.agents/harness/plugin.json"
    if [ ! -f "$manifest" ] || ! jq -e --arg s "--seat $cmd " '[.hooks.on_session_start[]?.command | contains($s)] | any' "$manifest" >/dev/null 2>&1 \
      || jq -e '(.env_passthrough // []) | index("BEADS_ACTOR")' "$manifest" >/dev/null 2>&1; then
      unwired="$unwired $cmd"
    fi
  done < <(jq -r '.seats[] | [.command, .harness] | @tsv' "$roster" 2>/dev/null)
  if [ -n "$unwired" ]; then
    add "seats wired" false warn "seats without a harness of their own that wakes them by name:$unwired" \
      "give each its own harnesses/<command>/ whose on_session_start hook runs scripts/wake.sh --seat <command>, with no BEADS_ACTOR in env_passthrough (the add-seat skill)"
  else
    add "seats wired" true info "$(jq '.seats | length' "$roster") seat(s), each with its own harness"
  fi

  # Every seat, the desk too, pushes what it wrote when its session ends.
  unpushed=""
  while IFS=$'\t' read -r cmd harness; do
    manifest="$dir/$harness/.agents/harness/plugin.json"
    if ! jq -e --arg s "--seat $cmd " '[.hooks.on_session_end[]?.command | contains($s) and contains("--end")] | any' "$manifest" >/dev/null 2>&1; then
      unpushed="$unpushed $cmd"
    fi
  done < <(jq -r '.seats[] | [.command, .harness] | @tsv' "$roster" 2>/dev/null)
  if [ -n "$unpushed" ]; then
    add "seats push at end" false warn "seats whose session end leaves their writes on this machine until the next push or wake:$unpushed" \
      "add to each harness's hooks: \"on_session_end\": [{\"command\": \"bash scripts/wake.sh --seat <command> --end || true\", \"timeout\": 30}] (needs ynh 0.14.0 or later), then ynh update"
  else
    add "seats push at end" true info "every seat's session-end hook pushes memory and work"
  fi

  # Every seat wakes by itself: its launch focus (ynh 0.15.0) opens a session
  # started by its name alone, so it never waits bare for the human to type.
  # And the folders it asks for (workspace) exist, or ynh refuses them.
  bare=""
  missing=""
  while IFS=$'\t' read -r cmd harness; do
    manifest="$dir/$harness/.agents/harness/plugin.json"
    if ! jq -e '.launch_focus as $f | $f != null and (.focuses // {} | has($f))' "$manifest" >/dev/null 2>&1; then
      bare="$bare $cmd"
    fi
    while IFS= read -r want; do
      [ -n "$want" ] || continue
      case "$want" in
        /*) path="$want" ;;
        "~/"*) path="$HOME/${want#\~/}" ;;
        *) path="$dir/$harness/$want" ;;
      esac
      [ -d "$path" ] || missing="$missing $cmd:$want"
    done < <(jq -r '.workspace[]? // empty' "$manifest" 2>/dev/null)
  done < <(jq -r '.seats[] | [.command, .harness] | @tsv' "$roster" 2>/dev/null)
  if [ -n "$bare" ]; then
    add "seats wake by themselves" false warn "seats that wait bare for the human when started by their name:$bare" \
      "give each a wake focus and \"launch_focus\": \"wake\" (the add-seat skill; needs ynh 0.15.0 or later), then ynh update"
  else
    add "seats wake by themselves" true info "every seat's launch focus starts its session"
  fi
  if [ -n "$missing" ]; then
    add "workspace folders" false warn "seats ask for folders that don't exist, which ynh refuses:$missing" \
      "check where each repository is checked out (the constitution's What it reaches), and fix the seat's workspace paths, which are relative to its own folder"
  else
    add "workspace folders" true info "every folder a seat asks for exists; granting them is the human's (ynh trust accept, or workspace_roots)"
  fi
  # Specialist workers hand their overflow to a general-purpose worker.
  specialists=$(jq -r '[.seats[] | select(.group == "workers" and ((.specialities // []) | length) > 0) | .command] | join(" ")' "$roster" 2>/dev/null)
  general=$(jq '[.seats[] | select(.group == "workers" and ((.specialities // []) | length) == 0)] | length' "$roster" 2>/dev/null)
  if [ -n "$specialists" ]; then
    if [ "${general:-0}" -eq 0 ]; then
      add "general worker" false warn "specialist workers ($specialists) but no general-purpose worker to take their overflow, or beads no specialist covers" \
        "seat a worker with no specialities (the add-seat skill)"
    else
      add "general worker" true info "$general general-purpose worker(s) beside the specialists"
    fi
  fi

  # A seat is born once its identity is pinned in its own namespace. Until then
  # its birth is owed: the human's for the desk, crew and standing roles, the
  # dispatcher's for a worker. It reads only the repository's own mount, which
  # ynm always names project, so a slow remote mount can't hold it up. Without
  # that mount (reported above) it doesn't run: ynm returns nothing, not an
  # error, for a mount that isn't there, and every seat would look unborn.
  if command -v ynm >/dev/null 2>&1 && [ "${projectmount:-0}" = 1 ]; then
    unborn=""
    unread=""
    while IFS=$'\t' read -r cmd by; do
      if ! found=$(cd "$dir" && ynm recall --mount project --namespace "seat/$cmd" --tags identity --json 2>/dev/null); then
        unread="$unread $cmd"
      elif ! jq -e --arg ns "seat/$cmd" '[.[]? | select(.namespace == $ns and .pinned == true)] | length > 0' <<<"$found" >/dev/null 2>&1; then
        unborn="$unborn $cmd (birth: $by)"
      fi
    done < <(jq -r '.seats[] | [.command, (.["seated-by"] // (if .group == "workers" then "the dispatcher" else "the human" end))] | @tsv' "$roster" 2>/dev/null)
    if [ -n "$unread" ]; then
      add "seats born" false warn "ynm couldn't recall the identities of:$unread, so whether they are born is unknown" \
        "run ynm recall --mount project --namespace seat/<command> --tags identity from the Wheelhouse root, and see ynm doctor"
    elif [ -n "$unborn" ]; then
      add "seats born" false warn "seats with no pinned identity in their own namespace, so not yet born:$unborn" \
        "start each for its birth (the birth skill); a seat writes who it is itself"
    else
      add "seats born" true info "every seat has a pinned identity in its own namespace: $(jq -r '[.seats[].command] | join(" ")' "$roster")"
    fi
  fi
fi

# --- shared ------------------------------------------------------------------
# Work and memory reach other machines only when pushed: the commits, and ynm's
# notes with them (the pre-push hook syncs memory).
if ! git -C "$dir" remote get-url origin >/dev/null 2>&1; then
  add "pushed" true info "no remote yet: work and memory stay on this machine until one is added and pushed"
elif ! git -C "$dir" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  add "pushed" false warn "the branch tracks no remote branch, so nothing has been pushed" \
    "git push -u origin $(git -C "$dir" branch --show-current 2>/dev/null || echo main)"
else
  ahead=$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
  if [ "${ahead:-0}" -gt 0 ]; then
    add "pushed" false warn "$ahead commit(s) not pushed to $(git -C "$dir" rev-parse --abbrev-ref '@{upstream}'), and the memory written since with them" \
      "git push (the pre-push hook syncs memory too)"
  else
    add "pushed" true info "up to date with $(git -C "$dir" rev-parse --abbrev-ref '@{upstream}') (as of the last fetch)"
  fi
fi

# The work graph isn't in git: a push doesn't carry it. With a git remote, the
# graph shares through a Dolt remote on the same repository, and pushes itself
# after each write once dolt.auto-push is on.
if command -v bd >/dev/null 2>&1 && [ -d "$dir/.beads" ] && url=$(git -C "$dir" remote get-url origin 2>/dev/null); then
  share="bd dolt remote add origin $url --allow-git-origin, then bd config set dolt.auto-push true and commit .beads/config.yaml, then bd dolt push"
  if ! (cd "$dir" && bd dolt remote list --json 2>/dev/null) | jq -e '(.data? // .) | length > 0' >/dev/null 2>&1; then
    add "work graph shared" false warn "the repository has a git remote but the work graph has no Dolt remote, so work stays on this machine (git push doesn't carry it)" "$share"
  elif [ "$(cd "$dir" && bd config get dolt.auto-push --json 2>/dev/null | jq -r '.value // empty')" != "true" ]; then
    add "work graph shared" false warn "the work graph has a Dolt remote but dolt.auto-push is off, so writes wait for a bd sync or a seat's next wake" \
      "bd config set dolt.auto-push true, and commit .beads/config.yaml"
  else
    add "work graph shared" true info "the work graph has a Dolt remote and pushes after each write"
  fi
fi

# Memory pushes itself too once sync.auto is on (ynm 0.5.0): ynm's stop hook
# syncs in the background after a turn, at most once an interval. ynm layers
# its config files, and the last one with a sync block wins.
if [ -f "$dir/.ynm/config.json" ] && git -C "$dir" remote get-url origin >/dev/null 2>&1; then
  syncblock=$(for f in "${YNM_HOME:-$HOME/.ynm}/config.json" "$dir/.ynm/config.json" "$dir/.ynm/config.local.json"; do
    [ -f "$f" ] && jq -c 'select(has("sync")) | .sync' "$f" 2>/dev/null
  done | tail -1)
  # ynm's config is strict: before 0.5.0 it refuses a sync block outright.
  ynmver=$(ynm --version 2>/dev/null | sed -n 's|^@ynm/cli/\([0-9]*\)\.\([0-9]*\)\..*|\1 \2|p')
  if [ -n "$syncblock" ] && [ -n "$ynmver" ] && [ "${ynmver% *}" -eq 0 ] && [ "${ynmver#* }" -lt 5 ]; then
    add "memory syncs itself" false error "ynm $(ynm --version 2>/dev/null | cut -d' ' -f1 | cut -d/ -f3) is older than 0.5.0, which refuses the config's sync block, so ynm can't read its config at all" \
      "brew upgrade ynm (0.5.0 or later)"
  elif [ "$(jq -r '.auto // false' <<<"${syncblock:-null}" 2>/dev/null)" = "true" ]; then
    add "memory syncs itself" true info "sync.auto is on: memory syncs after a turn, at most every $(jq -r '.intervalMinutes // 5' <<<"$syncblock") minutes"
  else
    add "memory syncs itself" false warn "sync.auto is off, so memory written mid-session waits for a git push, a wake or the session's end (which a crash skips)" \
      "add \"sync\": {\"auto\": true, \"intervalMinutes\": 5} to .ynm/config.json and commit it (ynm 0.5.0 or later)"
  fi
fi

jq -n --arg dir "$dir" --argjson checks "$checks" \
  '{ok: ([$checks[] | select(.level == "error" and .ok == false)] | length == 0), dir: $dir, checks: $checks}'
