#!/usr/bin/env bash
# shellcheck shell=bash
# --out FILE for this plugin's scripts: write the JSON a script prints to FILE
# as well as stdout, so a skill saves results with one plain script call. A
# shell redirect (> file.json) would stop the plugin's safety hook from
# auto-approving the call.
#
# Source it and call `with_out "$0" "$@"` before parsing arguments. Without
# --out it returns; with it, it runs the script again without --out, saves
# the output (whatever the exit code, so a partial result is kept), prints it
# and exits with the script's code.

with_out() {
  local script="$1" out="" pass=() rc=0
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out)
        out="${2:-}"
        shift 2 || {
          echo "Error: --out needs a file" >&2
          exit 1
        }
        ;;
      *) pass+=("$1"); shift ;;
    esac
  done
  [[ -n "$out" ]] || return 0
  mkdir -p "$(dirname "$out")"
  bash "$script" "${pass[@]}" >"$out.partial" || rc=$?
  if [[ -s "$out.partial" ]]; then
    mv "$out.partial" "$out"
    cat "$out"
  else
    rm -f "$out.partial"
  fi
  exit "$rc"
}
