#!/usr/bin/env bash
# Create the temporary work folder for one release, and say where it is.
# Usage: work-dir.sh <name>
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 3=could not create it

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: work-dir.sh <name>

Create (if needed) the work folder for one release and print its path. It
holds what a run makes along the way: disc reads, lookups, rips, encodes,
plans. It is temporary: nothing in it is the only copy of anything once a
disc is archived (the release record and cover go to the NAS with the WAVs),
so the system may clear it.

The base folder is MEDIA_MGMT_WORK_DIR if set, else "work_dir" in
config.json, else $TMPDIR/media-management. Never the user's Downloads or
home folder.

Arguments:
  name    Folder name, e.g. "cd-rip-New Order - (the best & the rest of) New Order".
          "/" and ":" become "_"
  --help  Show this help

Output: JSON to stdout
  {"work_dir": "/var/folders/.../T/media-management/cd-rip-...", "base": "...", "created": true}

Exit codes:
  0  Success
  1  Bad arguments
  3  The folder could not be created
HELP
}

NAME=""
for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *) NAME="$arg" ;;
  esac
done
if [[ -z "$NAME" ]]; then
  echo "Error: name argument required" >&2
  show_help >&2
  exit 1
fi

CONFIG_PATH="${MEDIA_MGMT_CONFIG_PATH:-$HOME/.config/media-management/config.json}"
base="${MEDIA_MGMT_WORK_DIR:-}"
if [[ -z "$base" && -f "$CONFIG_PATH" ]]; then
  base=$(jq -r '.work_dir // empty' "$CONFIG_PATH" 2>/dev/null || true)
fi
if [[ -z "$base" ]]; then
  tmp="${TMPDIR:-/tmp}"
  base="${tmp%/}/media-management"
fi

dir="$base/$(printf '%s' "$NAME" | tr '/:' '__')"
created=false
if [[ ! -d "$dir" ]]; then
  mkdir -p "$dir" || {
    echo "Error: could not create $dir" >&2
    exit 3
  }
  created=true
fi

jq -n --arg dir "$dir" --arg base "$base" --argjson created "$created" \
  '{work_dir: $dir, base: $base, created: $created}'
