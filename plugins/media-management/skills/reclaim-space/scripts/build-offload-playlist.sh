#!/usr/bin/env bash
# Build a playlist of cloud-backed tracks that are safe to offload locally.
# Usage: build-offload-playlist.sh [--playlist <name>] [--keep-folder <name>]
#                                  [--exclude-grouping <prefix>] [--exclude-kind <substr>]
#                                  [--replace]
# Output: JSON to stdout with the resulting counts
# Exit codes: 0=success, 1=bad args, 2=environment, 3=playlist exists (use --replace)
#
# NON-DESTRUCTIVE: this only creates/populates a playlist. It never removes
# downloads or deletes files. Freeing space is a deliberate manual step: open
# the playlist, select all, right-click -> Remove Download.

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: build-offload-playlist.sh [options]

Create a normal playlist populated with every library track that is safe to
offload: cloud-backed (Matched/Uploaded/Purchased/Subscription) and NOT in the
"keep" folder, NOT a protected Kind (e.g. WAV, which has no cloud copy), and NOT
carrying a protected Grouping prefix. You then select-all in that playlist and
"Remove Download" to reclaim disk — re-downloadable any time from the cloud.

This is a snapshot, not a Smart Playlist (Apple's automation cannot author Smart
Playlist rules). Re-run to refresh it, or see references/smart-playlist-recipe.md
to build the auto-updating Smart Playlist equivalent by hand.

Requires macOS with the Music app scriptable (Automation permission granted).

Options:
  --playlist <name>          Name of the playlist to create (default: "Offload — Cloud Safe")
  --keep-folder <name>       Folder whose playlists are protected (default: "Crates")
  --exclude-grouping <pfx>   Exclude tracks whose Grouping starts with <pfx> (default: none)
  --exclude-kind <substr>    Exclude tracks whose Kind contains <substr> (default: "WAV")
  --replace                  Delete any existing playlist of the same name first
  --help                     Show this help

Output: JSON to stdout
  {"playlist":"Offload — Cloud Safe","library_total":15743,"in_playlist":12104,
   "excluded":{"keep_folder":3001,"not_cloud_safe":22,"kind":56,"grouping":560}}

Exit codes:
  0  Success
  1  Bad arguments
  2  Environment error (not macOS, or Music not scriptable)
  3  A playlist of that name already exists (pass --replace to overwrite)
HELP
}

PLAYLIST="Offload — Cloud Safe"
KEEP_FOLDER="Crates"
EXCLUDE_GROUPING=""
EXCLUDE_KIND="WAV"
REPLACE="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --playlist)         [[ $# -ge 2 ]] || { echo "Error: --playlist requires a value" >&2; exit 1; };         PLAYLIST="$2"; shift 2 ;;
    --keep-folder)      [[ $# -ge 2 ]] || { echo "Error: --keep-folder requires a value" >&2; exit 1; };      KEEP_FOLDER="$2"; shift 2 ;;
    --exclude-grouping) [[ $# -ge 2 ]] || { echo "Error: --exclude-grouping requires a value" >&2; exit 1; }; EXCLUDE_GROUPING="$2"; shift 2 ;;
    --exclude-kind)     [[ $# -ge 2 ]] || { echo "Error: --exclude-kind requires a value" >&2; exit 1; };     EXCLUDE_KIND="$2"; shift 2 ;;
    --replace) REPLACE="1"; shift ;;
    *) echo "Error: unknown argument: $1" >&2; show_help >&2; exit 1 ;;
  esac
done

if ! command -v osascript >/dev/null 2>&1; then
  echo "Error: osascript not found — this skill requires macOS with Apple Music" >&2
  exit 2
fi

tmp=$(mktemp -t reclaim-build) || { echo "Error: mktemp failed" >&2; exit 2; }
trap 'rm -f "$tmp"' EXIT

cat > "$tmp" <<'OSA'
on run argv
	set playlistName to item 1 of argv
	set keepFolder to item 2 of argv
	set groupingPrefix to item 3 of argv
	set kindExclude to item 4 of argv
	set replaceFlag to item 5 of argv
	tell application "Music"
		with timeout of 3000 seconds
			set TB to (ASCII character 9)
			set TID to AppleScript's text item delimiters

			if replaceFlag is "1" then
				repeat with p in (every user playlist whose name is playlistName)
					try
						delete p
					end try
				end repeat
			else if (count of (every user playlist whose name is playlistName)) > 0 then
				return "EXISTS"
			end if

			-- Persistent IDs of every track inside the keep folder, as a delimited blob
			set keepBlob to "|"
			repeat with p in (every playlist)
				try
					if (name of (parent of p)) is keepFolder then
						set ids to (persistent ID of every track of p)
						if ids is not {} then
							set AppleScript's text item delimiters to "|"
							set keepBlob to keepBlob & (ids as text) & "|"
							set AppleScript's text item delimiters to TID
						end if
					end if
				end try
			end repeat

			set lib to library playlist 1
			set allRefs to (get every track of lib)
			set allPIDs to (get persistent ID of every track of lib)
			set allKinds to (get kind of every track of lib)
			set allGroup to (get grouping of every track of lib)
			set allCloud to (get cloud status of every track of lib)
			set n to count of allRefs

			set victor to (make new playlist with properties {name:playlistName})
			set inc to 0
			set exKeep to 0
			set exCloud to 0
			set exKind to 0
			set exGrp to 0

			repeat with i from 1 to n
				set pid to item i of allPIDs
				if (offset of ("|" & pid & "|") in keepBlob) > 0 then
					set exKeep to exKeep + 1
				else
					set cs to item i of allCloud
					if not (cs is matched or cs is uploaded or cs is purchased or cs is subscription) then
						set exCloud to exCloud + 1
					else
						set k to item i of allKinds
						try
							if k is missing value then set k to ""
						end try
						if (kindExclude is not "") and (k contains kindExclude) then
							set exKind to exKind + 1
						else
							set g to item i of allGroup
							try
								if g is missing value then set g to ""
							end try
							if (groupingPrefix is not "") and (g starts with groupingPrefix) then
								set exGrp to exGrp + 1
							else
								duplicate (item i of allRefs) to victor
								set inc to inc + 1
							end if
						end if
					end if
				end if
				if (i mod 1000) is 0 then log ("  processed " & i & "/" & n & " — added " & inc)
			end repeat

			set AppleScript's text item delimiters to TID
			return ((n as text) & TB & (inc as text) & TB & (exKeep as text) & TB & (exCloud as text) & TB & (exKind as text) & TB & (exGrp as text))
		end timeout
	end tell
end run
OSA

raw=$(osascript "$tmp" "$PLAYLIST" "$KEEP_FOLDER" "$EXCLUDE_GROUPING" "$EXCLUDE_KIND" "$REPLACE" 2>/tmp/reclaim-build-err-$$) || {
  echo "Error: Music is not scriptable. Open Apple Music and grant Automation" >&2
  echo "permission to your terminal, then retry. Details:" >&2
  sed 's/^/  /' "/tmp/reclaim-build-err-$$" >&2 2>/dev/null || true
  rm -f "/tmp/reclaim-build-err-$$"
  exit 2
}
rm -f "/tmp/reclaim-build-err-$$"

if [[ "$raw" == "EXISTS" ]]; then
  echo "Error: a playlist named \"$PLAYLIST\" already exists. Pass --replace to overwrite it." >&2
  exit 3
fi

IFS=$'\t' read -r total inc exKeep exCloud exKind exGrp <<<"$raw"

jq -n \
  --arg playlist "$PLAYLIST" \
  --argjson total "${total:-0}" \
  --argjson inc "${inc:-0}" \
  --argjson exKeep "${exKeep:-0}" \
  --argjson exCloud "${exCloud:-0}" \
  --argjson exKind "${exKind:-0}" \
  --argjson exGrp "${exGrp:-0}" \
  '{
    playlist: $playlist,
    library_total: $total,
    in_playlist: $inc,
    excluded: {keep_folder:$exKeep, not_cloud_safe:$exCloud, kind:$exKind, grouping:$exGrp}
  }'
