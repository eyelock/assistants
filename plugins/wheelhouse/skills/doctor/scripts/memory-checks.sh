#!/usr/bin/env bash
# The doctor's memory checks that depend on the backend, so check.sh stays small. The backend is
# wheelhouse.json's "memory" key (ynm when there is none), read through memory.sh: the Wheelhouse's
# own scripts/memory.sh, else the work-graph skill's. Read-only.
#
#   memory-checks.sh backend [--dir D]            print ynm or beads; exit 1 with the reason if it can't be told
#   memory-checks.sh beads   [--dir D]            print JSON check entries for Beads memory (readable, shared)
#   memory-checks.sh born    [--dir D] --seat C   print yes or no: C has a pinned identity; exit 1 if memory can't say
#   memory-checks.sh human   [--dir D] --name C   print yes or no: memory holds human/C
set -uo pipefail
cmd="${1:-}"; [ $# -eq 0 ] || shift
dir="." seat="" name=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="${2-}"; shift 2 || exit 1 ;;
    --seat) seat="${2-}"; shift 2 || exit 1 ;;
    --name) name="${2-}"; shift 2 || exit 1 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/wheelhouse-lib.sh" "$here/../../work-graph/scripts/wheelhouse-lib.sh"; do
  # shellcheck source=../../work-graph/scripts/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found beside $0 or in the work-graph skill's scripts folder" >&2; exit 3; }
memsh=""
for f in "$dir/scripts/memory.sh" "$here/../../work-graph/scripts/memory.sh"; do
  [ -f "$f" ] && { memsh="$f"; break; }
done
if ! backend=$(wl_backend "$dir"); then
  echo "wheelhouse.json: memory must be \"ynm\" or \"beads\", not \"$backend\""; exit 1
elif [ "$backend" = beads ] && [ -z "$memsh" ]; then
  echo "wheelhouse.json names a memory backend but there is no memory.sh"; exit 1
fi
yesno() { if [ "$(jq 'length' 2>/dev/null)" -gt 0 ] 2>/dev/null; then echo yes; else echo no; fi; }

case "$cmd" in
  backend) echo "$backend" ;;
  beads)
    out="[]"
    command -v bd >/dev/null 2>&1 && [ -d "$dir/.beads" ] || { echo "$out"; exit 0; }
    mem=$(cd "$dir" && limited "$WL_BD_SECS" bd --readonly memories --json 2>/dev/null)
    if jq -e 'type == "object"' >/dev/null 2>&1 <<<"$mem"; then
      out=$(jq -nc --argjson m "$mem" '[{name: "beads memory readable", ok: true, level: "info", detail: "\([$m | keys[] | select(. != "schema_version")] | length) memories", fix: null}]')
    else
      out=$(jq -nc --arg f "cd $dir && bd memories, and read the error" '[{name: "beads memory readable", ok: false, level: "error", detail: "bd --readonly memories --json gave no memory map", fix: $f}]')
    fi
    if [ "$(cd "$dir" && wl_dolt_remote "$WL_BD_SECS")" = yes ]; then
      jq -c '. + [{name: "beads memory shared", ok: true, level: "info", detail: "the work graph has a Dolt remote", fix: null}]' <<<"$out"
    else
      jq -c '. + [{name: "beads memory shared", ok: false, level: "warn", detail: "no Dolt remote, so memory stays on this machine", fix: "bd dolt remote add origin <git URL> --allow-git-origin, then bd dolt push"}]' <<<"$out"
    fi ;;
  born)
    # ynm: read from the project mount only, so a slow remote can't hold it up.
    wl_identity_pinned "$backend" "$dir" "$seat" "$memsh" || exit 1 ;;
  human)
    if [ "$backend" = beads ]; then bash "$memsh" recall --dir "$dir" --human "$name" --limit 1 2>/dev/null | yesno
    else limited "$WL_YNM_SECS" ynm recall --namespace "human/$name" --limit 1 --json 2>/dev/null | yesno; fi ;;
  *) echo "usage: memory-checks.sh backend|beads|born|human [--dir D] [--seat C|--name C]" >&2; exit 1 ;;
esac
