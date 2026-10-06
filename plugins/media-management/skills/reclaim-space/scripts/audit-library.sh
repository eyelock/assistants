#!/usr/bin/env bash
# Audit the Apple Music library for cloud-backed (safely offloadable) tracks.
# Usage: audit-library.sh [--keep-folder <name>]
# Output: JSON to stdout with cloud-status histogram and keep-folder playlists
# Exit codes: 0=success, 1=bad args, 2=environment (no osascript / Music unavailable)

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: audit-library.sh [--keep-folder <name>]

Read-only audit of the Apple Music library. Reports how many tracks are
cloud-backed (Matched/Uploaded/Purchased/Subscription) and therefore safe to
offload locally via "Remove Download", versus Ineligible (local-only, NOT
safe). Also lists the playlists inside the "keep" folder you want to protect.

Requires macOS with the Music app scriptable (Automation permission granted).

Arguments:
  --keep-folder <name>  Folder of playlists to report (default: "Crates")
  --help                Show this help

Output: JSON to stdout
  {
    "total_tracks": 15743,
    "cloud_status": {"matched":8987,"uploaded":6470,"purchased":29,
                     "subscription":216,"ineligible":0,"unknown":22,"other":19},
    "cloud_safe": 15702,
    "sync_library_likely_on": true,
    "keep_folder": "Crates",
    "keep_playlists": [{"name":"Loved Crate","tracks":1606}]
  }

Exit codes:
  0  Success
  1  Bad arguments
  2  Environment error (not macOS, or Music not scriptable)
HELP
}

KEEP_FOLDER="Crates"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --keep-folder)
      [[ $# -ge 2 ]] || { echo "Error: --keep-folder requires a value" >&2; exit 1; }
      KEEP_FOLDER="$2"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; show_help >&2; exit 1 ;;
  esac
done

if ! command -v osascript >/dev/null 2>&1; then
  echo "Error: osascript not found — this skill requires macOS with Apple Music" >&2
  exit 2
fi

# AppleScript is fed via a temp file and reads its parameters from argv, so
# playlist/folder names are never interpolated into the script text.
tmp=$(mktemp "${TMPDIR:-/tmp}/reclaim-audit.XXXXXX") || { echo "Error: mktemp failed" >&2; exit 2; }
err=$(mktemp "${TMPDIR:-/tmp}/reclaim-audit-err.XXXXXX") || { echo "Error: mktemp failed" >&2; exit 2; }
trap 'rm -f "$tmp" "$err"' EXIT

cat > "$tmp" <<'OSA'
on run argv
	set keepFolder to item 1 of argv
	tell application "Music"
		with timeout of 3000 seconds
			set TB to (ASCII character 9)
			set LF to (ASCII character 10)
			set lib to library playlist 1
			set outp to "TOTAL" & TB & (count of tracks of lib) & LF
			set outp to outp & "STATUS" & TB & "matched" & TB & (count of (every track of lib whose cloud status is matched)) & LF
			set outp to outp & "STATUS" & TB & "uploaded" & TB & (count of (every track of lib whose cloud status is uploaded)) & LF
			set outp to outp & "STATUS" & TB & "purchased" & TB & (count of (every track of lib whose cloud status is purchased)) & LF
			set outp to outp & "STATUS" & TB & "subscription" & TB & (count of (every track of lib whose cloud status is subscription)) & LF
			set outp to outp & "STATUS" & TB & "ineligible" & TB & (count of (every track of lib whose cloud status is ineligible)) & LF
			set outp to outp & "STATUS" & TB & "unknown" & TB & (count of (every track of lib whose cloud status is unknown)) & LF
			repeat with p in (every playlist)
				try
					if (name of (parent of p)) is keepFolder then
						set outp to outp & "KEEP" & TB & (name of p) & TB & (count of tracks of p) & LF
					end if
				end try
			end repeat
			return outp
		end timeout
	end tell
end run
OSA

raw=$(osascript "$tmp" "$KEEP_FOLDER" 2>"$err") || {
  echo "Error: Music is not scriptable. Open Apple Music and grant Automation" >&2
  echo "permission to your terminal, then retry. Details:" >&2
  sed 's/^/  /' "$err" >&2 2>/dev/null || true
  exit 2
}

# Plain variables, not an associative array: macOS ships bash 3.2.
total=0
s_matched=0 s_uploaded=0 s_purchased=0 s_subscription=0 s_ineligible=0 s_unknown=0
keep_json="[]"

while IFS=$'\t' read -r tag a b; do
  case "$tag" in
    TOTAL) total="${a:-0}" ;;
    STATUS)
      case "$a" in
        matched) s_matched="${b:-0}" ;;
        uploaded) s_uploaded="${b:-0}" ;;
        purchased) s_purchased="${b:-0}" ;;
        subscription) s_subscription="${b:-0}" ;;
        ineligible) s_ineligible="${b:-0}" ;;
        unknown) s_unknown="${b:-0}" ;;
      esac
      ;;
    KEEP) keep_json=$(jq --arg n "$a" --argjson c "${b:-0}" '. + [{name:$n, tracks:$c}]' <<<"$keep_json") ;;
  esac
done <<<"$raw"

safe=$(( s_matched + s_uploaded + s_purchased + s_subscription ))
known=$(( safe + s_ineligible + s_unknown ))
other=$(( total - known ))
[[ $other -lt 0 ]] && other=0
synced=false
[[ $safe -gt 0 ]] && synced=true

jq -n \
  --argjson total "$total" \
  --argjson matched "$s_matched" \
  --argjson uploaded "$s_uploaded" \
  --argjson purchased "$s_purchased" \
  --argjson subscription "$s_subscription" \
  --argjson ineligible "$s_ineligible" \
  --argjson unknown "$s_unknown" \
  --argjson other "$other" \
  --argjson safe "$safe" \
  --argjson synced "$synced" \
  --arg keep_folder "$KEEP_FOLDER" \
  --argjson keep "$keep_json" \
  '{
    total_tracks: $total,
    cloud_status: {matched:$matched, uploaded:$uploaded, purchased:$purchased,
                   subscription:$subscription, ineligible:$ineligible,
                   unknown:$unknown, other:$other},
    cloud_safe: $safe,
    sync_library_likely_on: $synced,
    keep_folder: $keep_folder,
    keep_playlists: $keep
  }'
