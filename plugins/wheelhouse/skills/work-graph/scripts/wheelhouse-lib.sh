#!/usr/bin/env bash
# wheelhouse-lib.sh: the helpers every wheelhouse script shares. Source it; never run it.
#
# A script sources it from beside itself, or from the work-graph skill's scripts folder (ynh delivers only skill folders, so the library rides in a skill every seat picks):
#
#   here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
#   for lib in "$here/wheelhouse-lib.sh" "$here/../../work-graph/scripts/wheelhouse-lib.sh"; do
#     [ -f "$lib" ] && { . "$lib"; break; }
#   done
#   type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found" >&2; exit 3; }
#
# Each helper is defined here and nowhere else. Names the scripts use without a prefix
# (limited, die, need) are the library's; the rest start with wl_. Nothing here runs at
# source time, sets shell options or exits the caller, except die and need, whose job is to.
#
# Interface
#   limited SECS CMD...      run CMD with a time limit; kills its whole process group on the
#                            alarm and exits 142. No perl: runs CMD unbounded and says so once.
#   die CODE MSG...          print "${WL_PREFIX}MSG" to stderr and exit CODE
#   need CMD                 die 3 "CMD is not installed" unless CMD is on PATH
#   bd_data                  stdin: a bd --json result, unwrapped from {"data": ...} when
#                            BD_JSON_ENVELOPE=1 wraps it; stdout: compact JSON
#   bd_first                 as bd_data, and the first element when the result is an array
#   WL_ROSTER_REL            the roster's path under a Wheelhouse's root
#   wl_valid_command C       C is a command name: lower-case letters, digits, hyphens
#   wl_backend [DIR]         print the memory backend (ynm or beads) from DIR/wheelhouse.json,
#                            ynm when there is no file or no key; return 2 on any other value
#   wl_is_trial_seat DIR C   C has no roster entry but a harness at DIR/harnesses/C/AGENTS.md
#   wl_is_seat ROSTER DIR C  C is in the roster's seats, or is a seat on trial
#   wl_default_humans ROSTER print how many humans the roster marks "default": true
#   wl_has_git_remote        the current git repository has a remote
#   wl_dolt_remote [SECS]    print yes, no or busy: whether bd has a Dolt remote; busy when the
#                            check gave up or failed (a bd that can't be reached is not "no")
#   wl_born_by ROSTER C      print who births seat C: its seated-by, the dispatcher for a
#                            worker, else the human
#   wl_identity_pinned BACKEND DIR C MEMORY_SH
#                            print yes or no: seat C has a pinned identity in its own memory
#                            (ynm: namespace seat/C, project mount; beads: through MEMORY_SH);
#                            return 1 when memory can't say
#   WL_JQ_MODELS             jq definitions: wl_tiers (the roster's tiers over the defaults)
#                            and wl_model($vendor) (for each seat: {seat, vendor, tier, model},
#                            model null when it has none on that vendor);
#                            use as: jq "$WL_JQ_MODELS"' ... ' roster.json
#
# Time limits, in seconds, each overridable by the environment: WL_BD_SECS (20), WL_YNM_SECS
# (30), WL_GH_SECS (30), WL_YNH_SECS (30), WL_SYNC_SECS (45). Every outside call (bd, gh, ynh,
# ynm) in a wheelhouse script goes through limited with one of them.

# shellcheck shell=bash

wl_loaded() { :; }

WL_PREFIX="${WL_PREFIX:-}"
# shellcheck disable=SC2034  # the library's interface, read by the scripts that source it
WL_ROSTER_REL=skills/roster/assets/roster.json
WL_BD_SECS="${WL_BD_SECS:-20}"
WL_YNM_SECS="${WL_YNM_SECS:-30}"
WL_GH_SECS="${WL_GH_SECS:-30}"
WL_YNH_SECS="${WL_YNH_SECS:-30}"
WL_SYNC_SECS="${WL_SYNC_SECS:-45}"

die() { local c=$1; shift; echo "${WL_PREFIX}$*" >&2; exit "$c"; }
need() { command -v "$1" >/dev/null 2>&1 || die 3 "$1 is not installed"; }

# A command that hangs gives up after SECS seconds (macOS has no timeout; perl's alarm does it).
# The command runs in its own process group and the whole group is killed on the alarm: a bd
# that has spawned a child would otherwise hold the output pipe open past the limit. Exit 142.
limited() {
  local secs="$1"; shift
  if command -v perl >/dev/null 2>&1; then
    perl -e 'my $s = shift; setpgrp(0, 0); my $p = fork; if (!$p) { exec @ARGV; exit 127 }
      $SIG{ALRM} = sub { $SIG{TERM} = "IGNORE"; kill "TERM", -$$; exit 142 };
      alarm $s; waitpid($p, 0); exit(($? & 127) ? 128 + ($? & 127) : $? >> 8)' -- "$secs" "$@"
  else
    [ -n "${WL_WARNED_NO_PERL:-}" ] || echo "wheelhouse-lib: perl is not installed, so '$1' runs with no time limit" >&2
    WL_WARNED_NO_PERL=1
    "$@"
  fi
}

# Beads' --json output is an array or an object, or {"data": ...} with BD_JSON_ENVELOPE=1.
bd_data() { jq -c '.data? // .'; }
bd_first() { jq -c '(.data? // .) | if type == "array" then .[0] else . end'; }

wl_valid_command() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }

wl_backend() {
  local b=ynm
  if [ -f "${1:-.}/wheelhouse.json" ]; then
    b=$(jq -r '.memory // "ynm"' "${1:-.}/wheelhouse.json" 2>/dev/null) || b=""
  fi
  printf '%s\n' "$b"
  case "$b" in ynm | beads) return 0 ;; *) return 2 ;; esac
}

wl_is_trial_seat() { [ -f "$1/harnesses/$2/AGENTS.md" ]; }

wl_is_seat() {
  jq -e --arg c "$3" '.seats | any(.command == $c)' "$1" >/dev/null 2>&1 && return 0
  wl_is_trial_seat "$2" "$3"
}

wl_default_humans() { jq '[(.humans // [])[] | select(.default == true)] | length' "$1"; }

wl_has_git_remote() { git remote 2>/dev/null | grep -q .; }

wl_dolt_remote() {
  local out rc
  out=$(limited "${1:-$WL_SYNC_SECS}" bd dolt remote list --json 2>/dev/null); rc=$?
  if [ "$rc" != 0 ]; then echo busy
  elif bd_data <<<"$out" 2>/dev/null | jq -e 'length > 0' >/dev/null 2>&1; then echo yes
  else echo no; fi
}

wl_born_by() {
  jq -r --arg s "$2" '
    (.seats[]? | select(.command == $s)) as $e
    | $e["seated-by"] // (if $e.group == "workers" then "the dispatcher" else "the human" end)' "$1" 2>/dev/null | head -1
}

wl_identity_pinned() {
  local found
  case "$1" in
    beads)
      found=$(bash "${4:?memory.sh path}" recall --dir "$2" --seat "$3" --kind identity --limit 1 2>/dev/null) || return 1
      jq -e 'length > 0' >/dev/null 2>&1 <<<"$found" && echo yes || echo no ;;
    ynm)
      found=$(cd "$2" && limited "$WL_YNM_SECS" ynm recall --mount project --namespace "seat/$3" --tags identity --json 2>/dev/null) || return 1
      jq -e --arg ns "seat/$3" '[.[]? | select(.namespace == $ns and .pinned == true)] | length > 0' >/dev/null 2>&1 <<<"$found" && echo yes || echo no ;;
    *) return 1 ;;
  esac
}

# shellcheck disable=SC2016,SC2034  # jq source, not shell; read by the scripts that source it
WL_JQ_MODELS='
def wl_tiers: ({fast: {claude: "sonnet"}, balanced: {claude: "sonnet"}, deep: {claude: "opus"}} * (.models.tiers // {}));
def wl_model($vendor): . as $root | (wl_tiers) as $tiers | .seats[]? | . as $s
  | ($s.model // ($root.models.groups // {})[$s.group]) as $tier
  | {seat: $s.command, vendor: $vendor, tier: $tier,
     model: ($s.models[$vendor] // (if $tier then $tiers[$tier][$vendor] else null end))};
'
