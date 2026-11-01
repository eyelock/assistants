#!/usr/bin/env bash
# Applies merged Wheelhouse changes after a pull, worked out from the git diff.
#
# It reads `git diff --name-only <from>..<to>` (default ORIG_HEAD..HEAD, which
# is what `git pull` just moved) and maps each path to what it needs:
#
#   harnesses/<seat>/...                 ynh install harnesses/<seat>
#   AGENTS.md, .agents/harness/plugin.json   ynh install . and every seat
#   skills/roster/...                    ynh install . and every seat
#   skills/<other>/...                   ynh install ., and each seat whose
#                                        `../..` include picks that skill
#   scripts/...                          restarts (hooks run these from disk)
#   a change to what ynh's trust covers   print `ynh trust accept local/<seat>`;
#                                        never run: accepting is the human's
#   anything else (docs, pinned-skills.md, .beads, ...)   nothing
#
# With no diff (nothing to compare, or --upstream) it also compares each
# seat's cached wheelhouse include with upstream (`ynh ls --check-updates`) and
# offers `ynh update`; --update runs it, then re-copies the plugin scripts the
# Wheelhouse already carries in scripts/ when they differ.
#
# Trust: ynh's digest covers a harness's sensors, hooks and MCP servers (top level and every
# profile), workspace, launch focus (with its prompt) and delegates_to focuses, and a seat whose digest changed or was never
# accepted loses its workspace folders until the human accepts again. So after
# the installs and updates it asks ynh (`ynh trust ls --format json`) and prints
# `ynh trust accept local/<seat>` for each roster seat that is `changed` or
# `unreviewed`. A change to any of those fields in the diff is also reported
# (the only evidence a --dry-run has, since it installs nothing).
#
# Every run also checks that each roster seat is installed (ynh ls) and born (a
# pinned identity in seat/<command>), and reports any that is not with the
# exact install command. It runs the safe steps, then the doctor, then prints
# the seats to restart. --dry-run only prints. It prints one JSON object.
#
# Exit codes: 0 done, 1 bad args, 2 not a Wheelhouse (or a bad revision),
# 3 a tool is missing or a step failed (the JSON says which).
set -uo pipefail

usage() {
  cat <<'EOF2'
Usage: refresh.sh [--dir <wheelhouse repo>] [--from <rev>] [--to <rev>] [<from>..<to>]
                  [--upstream] [--update] [--plugin <dir>] [--doctor <check.sh>]
                  [--dry-run]

Maps the git diff <from>..<to> (default ORIG_HEAD..HEAD) to the ynh installs,
trust instructions and restarts it needs, runs the safe ones, then the doctor,
and prints a JSON report. --dry-run only prints. --upstream (implied by an
empty diff) also compares each seat's wheelhouse include with upstream;
--update then runs `ynh update` and re-copies changed plugin scripts.
EOF2
}

dir="."
from=""
to=""
dry=0
upstream=0
update=0
plugin=""
doctor=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --from) [ $# -ge 2 ] || { usage >&2; exit 1; }; from="$2"; shift 2 ;;
    --to) [ $# -ge 2 ] || { usage >&2; exit 1; }; to="$2"; shift 2 ;;
    --plugin) [ $# -ge 2 ] || { usage >&2; exit 1; }; plugin="$2"; shift 2 ;;
    --doctor) [ $# -ge 2 ] || { usage >&2; exit 1; }; doctor="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    --upstream) upstream=1; shift ;;
    --update) update=1; upstream=1; shift ;;
    --help | -h) usage; exit 0 ;;
    *..*) from="${1%%..*}"; to="${1#*..}"; shift ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for t in jq git; do
  command -v "$t" >/dev/null 2>&1 || { echo "$t is required" >&2; exit 3; }
done
[ -d "$dir" ] || { echo "not a directory: $dir" >&2; exit 2; }
dir=$(cd "$dir" && pwd)
git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $dir" >&2; exit 2; }
[ -f "$dir/.agents/harness/plugin.json" ] || { echo "no desk harness at $dir/.agents/harness/plugin.json: not a Wheelhouse" >&2; exit 2; }

notes="[]"
note() { notes=$(jq -c --arg n "$1" '. + [$n]' <<<"$notes"); }
failed=0

# --- the seats -------------------------------------------------------------------
roster="$dir/skills/roster/assets/roster.json"
desk=$(jq -r '.name' "$dir/.agents/harness/plugin.json")
seats=""
if [ -f "$roster" ] && jq -e '.seats' "$roster" >/dev/null 2>&1; then
  desk=$(jq -r --arg d "$desk" '[.seats[] | select(.group == "desk") | .command][0] // $d' "$roster")
  seats=$(jq -r --arg d "$desk" '.seats[] | select(.command != $d) | .command' "$roster")
else
  note "no roster at $roster: seats are the folders under harnesses/"
  for p in "$dir"/harnesses/*/; do [ -d "$p" ] && seats="$seats$(basename "$p")"$'\n'; done
fi

# --- the diff ----------------------------------------------------------------------
[ -n "$to" ] || to="HEAD"
if [ -z "$from" ]; then
  git -C "$dir" rev-parse -q --verify ORIG_HEAD >/dev/null 2>&1 && from="ORIG_HEAD"
fi
files=""
range=""
if [ -n "$from" ]; then
  git -C "$dir" rev-parse -q --verify "$from^{commit}" >/dev/null 2>&1 || { echo "not a revision: $from" >&2; exit 2; }
  git -C "$dir" rev-parse -q --verify "$to^{commit}" >/dev/null 2>&1 || { echo "not a revision: $to" >&2; exit 2; }
  range="$from..$to"
  files=$(git -C "$dir" diff --name-only --no-renames "$from" "$to")
fi
[ -n "$files" ] || upstream=1

# Whether a seat's harness includes this repository's skill (../.. with no pick, or picking it).
seat_picks() {
  local f="$dir/harnesses/$1/.agents/harness/plugin.json"
  [ -f "$f" ] || return 1
  jq -e --arg s "$2" '[.includes[]? | select(.git == "../..") | (if .pick then (.pick | index($s) != null) else true end)] | any' "$f" >/dev/null 2>&1
}
# What ynh's trust digest covers in a plugin.json (ynh cmd/ynh/trust.go): workspace; sensors, hooks and
# MCP servers at the top level and in every profile; the launch focus (its name, and the profile and
# prompt of that entry in focuses); and each delegates_to entry with the focus it selects. The prompt
# of a delegate's focus lives in the delegate's own harness, so only the entry shows in this diff.
trust_of() {
  git -C "$dir" show "$1:$2" 2>/dev/null | jq -cS '{
    workspace, sensors, hooks, mcp_servers, launch_focus,
    launch_focus_entry: (if .launch_focus then (.focuses[.launch_focus] // null) else null end),
    profiles: ((.profiles // {}) | map_values({hooks, mcp_servers, sensors} | with_entries(select(.value != null))) | with_entries(select(.value != {}))),
    delegates_to: [.delegates_to[]? | {git, ref, path, profile, focus}]}' 2>/dev/null || echo "null"
}
# A harness new in the range has no earlier digest to differ from: ynh's own listing reports it.
trust_changed() { local o; o=$(trust_of "$from" "$1"); [ "$o" != "null" ] && [ "$o" != "$(trust_of "$to" "$1")" ]; }

desk_install=0
seat_install=""
trust=""
restart_all=0
scripts_changed=""
ignored=""
removed=""
is_seat() { printf '%s\n' "$seats" | grep -qx -- "$1"; }
all_seats() { for s in $seats; do [ -d "$dir/harnesses/$s" ] && echo "$s"; done; }

while IFS= read -r path; do
  [ -n "$path" ] || continue
  case "$path" in
    harnesses/*/*)
      seat=${path#harnesses/}; seat=${seat%%/*}
      case "$path" in
        harnesses/"$seat"/.agents/harness/pinned-skills.md) ignored="$ignored$path"$'\n'; continue ;;
      esac
      if [ ! -d "$dir/harnesses/$seat" ]; then
        removed="$removed$seat"$'\n'; continue
      fi
      seat_install="$seat_install$seat"$'\n'
      if [ "$path" = "harnesses/$seat/.agents/harness/plugin.json" ]; then
        trust_changed "$path" && trust="$trust$seat"$'\n'
      fi ;;
    AGENTS.md | .agents/harness/plugin.json)
      desk_install=1; seat_install="$seat_install$(all_seats)"$'\n'
      if [ "$path" = ".agents/harness/plugin.json" ]; then
        trust_changed "$path" && trust="$trust$desk"$'\n'
      fi ;;
    skills/roster/*)
      desk_install=1; seat_install="$seat_install$(all_seats)"$'\n' ;;
    skills/*/*)
      desk_install=1
      sk=${path#skills/}; sk="skills/${sk%%/*}"
      for s in $(all_seats); do seat_picks "$s" "$sk" && seat_install="$seat_install$s"$'\n'; done ;;
    scripts/*)
      scripts_changed="$scripts_changed$path"$'\n'; restart_all=1 ;;
    *) ignored="$ignored$path"$'\n' ;;
  esac
done <<<"$files"

lines_json() { printf '%s' "$1" | jq -Rn '[inputs | select(length > 0)] | unique'; }
seat_install=$(printf '%s' "$seat_install" | sort -u | sed '/^$/d')
[ -z "$(printf '%s' "$removed" | sed '/^$/d')" ] || \
  for r in $(printf '%s' "$removed" | sort -u); do note "harnesses/$r is gone from the repository: ynh uninstall local/$r removes the installed seat (not run)"; done

# --- run the installs ------------------------------------------------------------------
ynh_ok=1
command -v ynh >/dev/null 2>&1 || ynh_ok=0
ran="[]"
record() { ran=$(jq -c --arg c "$1" --argjson ok "$2" --arg o "$3" '. + [{command: $c, ok: $ok, output: $o}]' <<<"$ran"); }
run_step() { # run_step <display command> <args...>, from the Wheelhouse root
  local disp="$1" out; shift
  if out=$(cd "$dir" && "$@" 2>&1); then record "$disp" true "$(printf '%s' "$out" | tail -3)"
  else record "$disp" false "$(printf '%s' "$out" | tail -3)"; failed=1; fi
}
planned="[]"
plan() { planned=$(jq -c --arg c "$1" '. + [$c]' <<<"$planned"); }
[ "$desk_install" = 1 ] && plan "ynh install ."
for s in $seat_install; do plan "ynh install harnesses/$s"; done

if [ "$(jq length <<<"$planned")" -gt 0 ] && [ "$dry" = 0 ]; then
  if [ "$ynh_ok" = 0 ]; then
    note "ynh is not on PATH: nothing was installed"; failed=1
  else
    [ "$desk_install" = 1 ] && run_step "ynh install ." ynh install .
    for s in $seat_install; do run_step "ynh install harnesses/$s" ynh install "harnesses/$s"; done
  fi
fi

# --- upstream: the cached wheelhouse include against the plugin's upstream -----------
updates="[]"
scripts_stale="[]"
copied="[]"
if [ "$upstream" = 1 ]; then
  if [ "$ynh_ok" = 0 ]; then
    note "ynh is not on PATH: upstream not checked"
  elif listing=$(ynh ls --check-updates --format json 2>/dev/null) && jq -e '.harnesses' >/dev/null 2>&1 <<<"$listing"; then
    updates=$(jq -c --arg d "$desk" --arg seats "$desk $(printf '%s' "$seats" | tr '\n' ' ')" '
      [ .harnesses[] | select(.id | startswith("local/")) | select(.name as $n | ($seats | split(" ") | index($n)) != null)
        | . as $h | .includes[]? | select((.path // "") | endswith("plugins/wheelhouse"))
        | select((.is_pinned | not) and (.ref_available // "") != "" and .ref_installed != .ref_available)
        | {seat: $h.name, installed: .ref_installed, available: .ref_available, command: ("ynh update " + $h.id)} ]' <<<"$listing")
    if [ "$update" = 1 ] && [ "$dry" = 0 ]; then
      while IFS= read -r c; do [ -n "$c" ] && run_step "$c" $c; done < <(jq -r '.[].command' <<<"$updates")
      listing=$(ynh ls --check-updates --format json 2>/dev/null || echo "$listing")
    fi
    # The plugin's own copy of the scripts the Wheelhouse carries: the ynh cache checkout at upstream.
    if [ -z "$plugin" ]; then
      want=$(jq -r '[.harnesses[]?.includes[]? | select((.path // "") | endswith("plugins/wheelhouse")) | .ref_available][0] // empty' <<<"$listing")
      for c in "${YNH_HOME:-$HOME/.ynh}"/cache/*/; do
        [ -d "${c}plugins/wheelhouse" ] || continue
        [ -n "$want" ] && [ "$(git -C "$c" rev-parse HEAD 2>/dev/null)" = "$want" ] && plugin="${c}plugins/wheelhouse" && break
      done
    fi
    if [ -n "$plugin" ] && [ -d "$plugin/skills" ]; then
      for f in $(cd "$plugin/skills" && ls */scripts/*.sh */scripts/*.jq 2>/dev/null); do
        b=$(basename "$f")
        [ -f "$dir/scripts/$b" ] || continue
        cmp -s "$plugin/skills/$f" "$dir/scripts/$b" && continue
        scripts_stale=$(jq -c --arg b "scripts/$b" '. + [$b]' <<<"$scripts_stale")
        if [ "$update" = 1 ] && [ "$dry" = 0 ]; then
          cp "$plugin/skills/$f" "$dir/scripts/$b" && copied=$(jq -c --arg b "scripts/$b" '. + [$b]' <<<"$copied")
        fi
      done
    else
      note "plugin checkout at upstream not found in the ynh cache: plugin scripts not compared (pass --plugin <dir>)"
    fi
  else
    note "ynh ls --check-updates gave no listing: upstream not checked"
  fi
fi
[ "$(jq length <<<"$copied")" -gt 0 ] && restart_all=1

# --- installed and born -------------------------------------------------------------------
installed_json="null"
if [ "$ynh_ok" = 1 ] && l=$(ynh ls --format json 2>/dev/null) && jq -e '.harnesses' >/dev/null 2>&1 <<<"$l"; then
  installed_json=$(jq -c '[.harnesses[].name]' <<<"$l")
fi
missing="[]"
for s in $desk $seats; do
  [ -n "$s" ] || continue
  if [ "$s" = "$desk" ]; then cmd="ynh install ."; birth="the human"; else cmd="ynh install harnesses/$s"; birth="the human"; fi
  jq -e --arg s "$s" '.seats[]? | select(.command == $s and .group == "workers")' "$roster" >/dev/null 2>&1 && birth="the dispatcher"
  by=$(jq -r --arg s "$s" '.seats[]? | select(.command == $s) | .["seated-by"] // empty' "$roster" 2>/dev/null)
  [ -n "$by" ] && jq -e --arg s "$s" '.seats[] | select(.command == $s and .group != "workers")' "$roster" >/dev/null 2>&1 && birth="$by"
  inst="null"
  [ "$installed_json" != "null" ] && inst=$(jq -c --arg s "$s" 'index($s) != null' <<<"$installed_json")
  born="null"
  if command -v ynm >/dev/null 2>&1 && found=$(cd "$dir" && ynm recall --mount project --namespace "seat/$s" --tags identity --json 2>/dev/null); then
    born=$(jq -c --arg ns "seat/$s" '[.[]? | select(.namespace == $ns and .pinned == true)] | length > 0' <<<"$found" 2>/dev/null || echo null)
  fi
  if [ "$inst" = "false" ] || [ "$born" = "false" ]; then
    missing=$(jq -c --arg s "$s" --argjson i "$inst" --argjson b "$born" --arg c "$cmd" --arg by "$birth" \
      '. + [{seat: $s, installed: $i, born: $b, install: (if $i == false then $c else null end),
             reminder: (if $b == false then ("birth is " + $by + "'"'"'s: start the seat for its birth (the birth skill)") else null end)}]' <<<"$missing")
  fi
done

# --- trust: what ynh says is not accepted ---------------------------------------------------
# Read after the installs and updates, so it sees what they changed. A dry run installs nothing,
# so it can only say what the diff suggests.
if [ "$ynh_ok" = 1 ]; then
  if tl=$(ynh trust ls --format json 2>/dev/null) && jq -e 'type == "array"' >/dev/null 2>&1 <<<"$tl"; then
    for s in $desk $seats; do
      [ -n "$s" ] || continue
      st=$(jq -r --arg id "local/$s" '[.[] | select(.harness == $id) | .state][0] // empty' <<<"$tl")
      case "$st" in
        changed | unreviewed) trust="$trust$s"$'\n' ;;
        unavailable)
          why=$(jq -r --arg id "local/$s" '[.[] | select(.harness == $id) | (.problems // [])[]] | join("; ")' <<<"$tl")
          note "local/$s is unavailable to ynh trust: what it runs could not be read in full${why:+ ($why)}. It gets none of its workspace folders, and ynh trust accept does not fix it: ynh update local/$s fetches the missing include (then run refresh again)" ;;
      esac
    done
    [ "$dry" = 1 ] && [ "$(jq length <<<"$planned")" -gt 0 ] && note "dry run: trust was read before the installs, so a seat they would change is not listed"
  else
    note "ynh trust ls gave no listing: trust not checked"
  fi
fi

# --- the doctor ---------------------------------------------------------------------------
doctor_json="null"
if [ -z "$doctor" ]; then
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  [ -f "$here/../../doctor/scripts/check.sh" ] && doctor="$here/../../doctor/scripts/check.sh"
fi
if [ "$dry" = 1 ]; then
  [ -n "$doctor" ] && doctor_json='"skipped: dry run"'
elif [ -n "$doctor" ] && [ -f "$doctor" ]; then
  if out=$(bash "$doctor" --dir "$dir" 2>/dev/null) && jq -e '.checks' >/dev/null 2>&1 <<<"$out"; then
    doctor_json=$(jq -c '{ok, failing: [.checks[] | select(.ok == false) | {name, level, detail, fix}]}' <<<"$out")
  else
    doctor_json='"the doctor gave no report"'; note "the doctor gave no report: run it by hand"
  fi
else
  note "the doctor was not found: run the doctor skill by hand"
fi

# --- restarts and the report ----------------------------------------------------------------
if [ "$restart_all" = 1 ]; then restart=$(printf '%s\n%s\n' "$desk" "$(all_seats)")
else
  restart=""
  [ "$desk_install" = 1 ] && restart="$desk"$'\n'
  restart="$restart$seat_install"
fi
trust_cmds=$(printf '%s' "$trust" | sort -u | sed '/^$/d' | while IFS= read -r s; do echo "ynh trust accept local/$s"; done)

jq -n --arg range "$range" --argjson dry "$([ "$dry" = 1 ] && echo true || echo false)" \
  --argjson install "$planned" --argjson ran "$ran" --argjson failed "$([ "$failed" = 1 ] && echo true || echo false)" \
  --argjson trust "$(lines_json "$trust_cmds")" --argjson restart "$(lines_json "$restart")" \
  --argjson scripts "$(lines_json "$scripts_changed")" --argjson ignored "$(lines_json "$ignored")" \
  --argjson updates "$updates" --argjson stale "$scripts_stale" --argjson copied "$copied" \
  --argjson missing "$missing" --argjson doctor "$doctor_json" --argjson notes "$notes" \
  '{range: (if $range == "" then null else $range end), dryRun: $dry, failed: $failed,
    install: $install, ran: $ran,
    trust: $trust, restart: $restart, scriptsChanged: $scripts, ignored: $ignored,
    upstream: {updates: $updates, pluginScriptsDiffer: $stale, pluginScriptsCopied: $copied},
    seatsNotReady: $missing, doctor: $doctor, notes: $notes}'
[ "$failed" = 0 ] || exit 3
