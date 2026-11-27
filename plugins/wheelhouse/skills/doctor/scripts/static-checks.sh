#!/usr/bin/env bash
# The doctor's checks of a Wheelhouse repository's own files, which need no ynm, no bd, no git remote and no
# network: no copy of a plugin script left in scripts/, every seat started by its own name, exactly one default
# human, and no Beads agent setup. check.sh adds them to its report; the rule sensors (sensors/rules/) run
# them under `ynh check` in CI, so one definition serves both.
#
# Output: a JSON array of {name, ok, level, detail, fix}, the shape of check.sh's "checks". Read-only.
# Exit codes: 0 the checks ran (read each "ok"), 1 bad args, 2 directory not found, 3 jq or the library is missing.
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: static-checks.sh [--dir <wheelhouse repo>]

Prints, as a JSON array, the doctor's checks that read only the files of the Wheelhouse repository at --dir
(default: the current directory). Changes nothing.
USAGE
}

dir="."
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --help | -h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/wheelhouse-lib.sh" "$here/../../work-graph/scripts/wheelhouse-lib.sh"; do
  # shellcheck source=../../work-graph/scripts/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found beside $0 or in the work-graph skill's scripts folder" >&2; exit 3; }
need jq
[ -d "$dir" ] || { echo "not a directory: $dir" >&2; exit 2; }
dir=$(cd "$dir" && pwd)

checks="[]"
# add <name> <ok:true|false> <level:info|warn|error> <detail> [fix]
add() {
  checks=$(jq -c --arg n "$1" --argjson ok "$2" --arg l "$3" --arg d "$4" --arg f "${5:-}" \
    '. + [{name: $n, ok: $ok, level: $l, detail: $d, fix: (if $f == "" then null else $f end)}]' <<<"$checks")
}

# A copy of a plugin script left in the Wheelhouse's scripts/ is a fork: the plugin's fixes never reach it, and no seat
# runs it unless something still names it. Seats run the plugin's scripts; a Wheelhouse keeps only its own.
copies=""
for f in "$here"/../../*/scripts/*.sh "$here"/../../*/scripts/*.jq; do
  [ -f "$f" ] || continue
  b=$(basename "$f")
  [ -f "$dir/scripts/$b" ] && copies="$copies scripts/$b"
done
if [ -n "$copies" ]; then
  add "plugin script copies" false warn "the Wheelhouse keeps copies of the plugin's scripts, which the plugin's fixes never reach:$copies" \
    "delete them, and point hooks and docs at the installed scripts (the work-graph skill's \"Where the scripts are\"); a script of the Wheelhouse's own with one of these names has to be renamed"
else
  add "plugin script copies" true info "scripts/ holds none of the plugin's scripts"
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
# Every seat in the roster but the desk has a harness of its own whose wake hook
# names it, and none passes BEADS_ACTOR through (a seat names itself).
roster="$dir/$WL_ROSTER_REL"
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
      "give each its own harnesses/<command>/ whose on_session_start hook runs the installed wake.sh with --seat <command> (the wake skill's "The hook command"), with no BEADS_ACTOR in env_passthrough (the add-seat skill)"
  else
    add "seats wired" true info "$(jq '.seats | length' "$roster") seat(s), each with its own harness"
  fi

  # Exactly one human is the default: the name for work that needs a human but no particular one.
  defaults=$(wl_default_humans "$roster" 2>/dev/null || echo 0)
  if [ "${defaults:-0}" -eq 1 ]; then
    add "default human" true info "$(jq -r '[.humans[] | select(.default == true)][0] | "\(.name) (\(.command))"' "$roster"), and no other human in the roster"
  elif [ "${defaults:-0}" -eq 0 ]; then
    add "default human" false warn "the roster has no default human, so work that needs a human has nowhere to go and the desk's wake shows no inbox" \
      "add to the roster's humans one entry with \"default\": true: {\"name\": \"<Name>\", \"command\": \"<name>\", \"pronouns\": \"they/them\", \"default\": true}, named with the human (create-wheelhouse, question 5)"
  else
    add "default human" false error "the roster has $defaults default humans ($(jq -r '[.humans[] | select(.default == true) | .command] | join(", ")' "$roster")); the inbox needs exactly one" \
      "ask the human which is the default, and remove \"default\": true from the others"
  fi
fi

printf '%s\n' "$checks"
