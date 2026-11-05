#!/usr/bin/env bash
# The library model's variables come from library.env, sourced below.
# shellcheck disable=SC2154
# Stand-in for osascript in the media-management eval sandboxes: plays the
# Apple Music app for the plugin's own AppleScripts, from the library model in
# .eval/music/library.env (written by sandbox.sh's install_music_stub).
#
# Answers: the genre list (extract-apple-music-genres.sh), the reclaim-space
# audit (audit-library.sh), the offload-playlist build
# (build-offload-playlist.sh, honouring its arguments), and, from the track
# library in music-model.py, audit-release's track listing, retagging and
# track removal. Playlists it makes are
# kept in .eval/music/playlists, one "name<TAB>tracks" line each. Every call is
# logged to $EVAL_STUB_LOG with a label; any other script fails the way Music
# does when automation is not allowed.
# Exit codes: 0 success, 1 the AppleScript failed.
set -uo pipefail

state="$(cd "$(dirname "$0")/.." && pwd)/music"
log="${EVAL_STUB_LOG:-$state/../stub-calls.log}"
# shellcheck source=/dev/null
source "$state/library.env"

if [[ "${1:-}" == "-e" ]]; then
  script="${2:-}"
  shift 2 || true
else
  script=$(cat "${1:-/dev/null}" 2>/dev/null || true)
  shift || true
fi

if [[ "$script" == *"persistent ID of ts"* ]]; then
  label="list-tracks"
elif [[ "$script" == *"set album artist of t"* ]]; then
  label="retag"
elif [[ "$script" == *"persistent ID is"* && "$script" == *"delete t"* ]]; then
  # remove-tracks.sh: a look, or (with "delete") a destructive call.
  if [[ "${2:-}" == "delete" ]]; then label="DESTRUCTIVE remove-tracks"; else label="look-tracks"; fi
elif [[ "$script" == *"make new playlist"* ]]; then
  label="build-offload-playlist"
elif [[ "$script" == *"cloud status is matched"* ]]; then
  label="audit-library"
elif [[ "$script" == *"name of every genre"* || "$script" == *"genre of t"* ]]; then
  label="list-genres"
elif [[ "$script" == *"remove"* || "$script" == *"delete"* ]]; then
  label="DESTRUCTIVE"
else
  label="other"
fi

{
  printf 'osascript [%s]' "$label"
  for a in "$@"; do printf ' %q' "$a"; done
  if [[ "$label" == "other" || "$label" == "DESTRUCTIVE" ]]; then
    printf ' script=%q' "$(printf '%s' "$script" | tr '\n\t' '  ' | cut -c1-300)"
  fi
  printf '\n'
} >>"$log"

model() {
  python3 -I "$(dirname "$0")/../music/music-model.py" "$state" "$@"
}

case "$label" in
  list-tracks)
    model list "$@"
    ;;
  retag)
    model retag "$@"
    ;;
  look-tracks)
    model remove "${1:-}" look
    ;;
  "DESTRUCTIVE remove-tracks")
    model remove "${1:-}" delete
    ;;
  list-genres)
    echo "$genres"
    ;;
  audit-library)
    keep="${1:-Crates}"
    printf 'TOTAL\t%s\n' "$total"
    for s in matched uploaded purchased subscription ineligible unknown; do
      printf 'STATUS\t%s\t%s\n' "$s" "${!s}"
    done
    if [[ "$keep" == "$keep_folder" && "$keep_tracks" -gt 0 ]]; then
      printf 'KEEP\tLast 30 Days\t%s\n' $((keep_tracks / 3))
      printf 'KEEP\tHouse Crate\t%s\n' $((keep_tracks / 3))
      printf 'KEEP\tTechno Crate\t%s\n' $((keep_tracks - 2 * (keep_tracks / 3)))
    fi
    ;;
  build-offload-playlist)
    name="${1:-}" keep="${2:-}" grouping="${3:-}" kind="${4:-}" replace="${5:-0}"
    if [[ "$replace" != "1" ]] && cut -f1 "$state/playlists" | grep -Fxq -- "$name"; then
      echo "EXISTS"
      exit 0
    fi
    if [[ "$replace" == "1" ]]; then
      awk -F '\t' -v n="$name" '$1 != n' "$state/playlists" >"$state/playlists.new"
      mv "$state/playlists.new" "$state/playlists"
    fi
    safe=$((matched + uploaded + purchased + subscription))
    ex_cloud=$((total - safe))
    ex_keep=0
    [[ -n "$keep" && "$keep" == "$keep_folder" ]] && ex_keep=$keep_tracks
    [[ $ex_keep -gt $safe ]] && ex_keep=$safe
    left=$((safe - ex_keep))
    ex_kind=0
    [[ -n "$kind" && "WAV audio file" == *"$kind"* ]] && ex_kind=$wav_tracks
    [[ $ex_kind -gt $left ]] && ex_kind=$left
    left=$((left - ex_kind))
    ex_grp=0
    [[ -n "$grouping" && "DJ Set" == "$grouping"* ]] && ex_grp=$dj_grouping_tracks
    [[ $ex_grp -gt $left ]] && ex_grp=$left
    inc=$((left - ex_grp))
    printf '%s\t%s\n' "$name" "$inc" >>"$state/playlists"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$total" "$inc" "$ex_keep" "$ex_cloud" "$ex_kind" "$ex_grp"
    ;;
  *)
    echo "execution error: Not authorized to send Apple events to Music. (-1743)" >&2
    exit 1
    ;;
esac
