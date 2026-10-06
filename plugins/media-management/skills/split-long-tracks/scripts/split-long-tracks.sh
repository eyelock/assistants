#!/usr/bin/env bash
# Detect and split audio tracks exceeding a duration limit at silence points.
# Usage: split-long-tracks.sh <file-or-folder> [max-minutes]
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=file not found, 3=ffmpeg error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: split-long-tracks.sh <file-or-folder> [max-minutes]

Detect audio tracks exceeding max-minutes (default: 78) and split them
at quiet sections using ffmpeg silencedetect. Adds 2s fade in/out at
split points.

Split files replace the original — no "Part X" suffixes. A track alone in
its folder becomes a mini-album: "01 Title.mp3", "02 Title.mp3", tagged
1/N, 2/N. A track inside an album keeps its place: parts are named after the
original file ("03 Title 1.mp3", "03 Title 2.mp3") and keep its track number;
run update-track-count.sh afterwards to renumber the album.

Output: JSON to stdout
  {"splits": [{"file": "...", "parts": N, "durations": [...]}], "skipped": [...]}
HELP
}

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
  esac
done

TARGET="${1:-}"
MAX_MINUTES="${2:-78}"

if [[ -z "$TARGET" ]]; then
  echo "Error: file or folder argument required" >&2
  exit 1
fi
if [[ ! -e "$TARGET" ]]; then
  echo "Error: path not found: $TARGET" >&2
  exit 2
fi

# Convert max minutes to integer seconds for comparison
MAX_SECONDS_RAW=$(echo "$MAX_MINUTES * 60" | bc)
MAX_SECONDS=${MAX_SECONDS_RAW%%.*}

# Collect files to check
files=()
if [[ -d "$TARGET" ]]; then
  while IFS= read -r f; do files+=("$f"); done < <(find "$TARGET" -maxdepth 1 -iname '*.mp3' -type f | sort)
else
  files=("$TARGET")
fi

splits_json="[]"
skipped_json="[]"

for f in "${files[@]}"; do
  # Get duration as float
  duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null || echo "0")
  # Integer seconds for comparison
  duration_int=${duration%%.*}
  duration_int=${duration_int:-0}

  if [[ $duration_int -le $MAX_SECONDS ]]; then
    skipped_json=$(echo "$skipped_json" | jq --arg file "$(basename "$f")" --arg dur "$duration" \
      '. + [{"file": $file, "duration_seconds": ($dur | tonumber)}]')
    continue
  fi

  echo "Splitting: $(basename "$f") (${duration_int}s > ${MAX_SECONDS}s limit)" >&2

  # Find silence points using silencedetect
  silence_output=$(ffmpeg -i "$f" -af "silencedetect=noise=-30dB:d=0.5" -f null - 2>&1 || true)
  # Extract silence_end timestamps (macOS-compatible grep)
  silence_ends=$(echo "$silence_output" | grep 'silence_end:' | sed 's/.*silence_end: *\([0-9.]*\).*/\1/' || true)

  # Calculate target segment duration
  num_parts=$(( (duration_int / MAX_SECONDS) + 1 ))
  target_segment=$(echo "$duration / $num_parts" | bc -l)

  # Find the best split points near each target boundary
  split_points=()
  for ((p = 1; p < num_parts; p++)); do
    target_time=$(echo "$target_segment * $p" | bc -l)

    # Find the silence point closest to target_time (float comparison via bc)
    best_point=""
    best_diff="999999"
    while IFS= read -r se; do
      [[ -z "$se" ]] && continue
      diff=$(echo "($se) - ($target_time)" | bc -l)
      # Absolute value: strip leading minus
      abs_diff="${diff#-}"
      if echo "$abs_diff < $best_diff" | bc -l | grep -q '^1'; then
        best_diff="$abs_diff"
        best_point="$se"
      fi
    done <<< "$silence_ends"

    if [[ -n "$best_point" ]]; then
      split_points+=("$best_point")
    else
      # No silence found — split at target time
      split_points+=("$(printf '%.3f' "$target_time")")
    fi
  done

  # Get metadata from original for copying
  dir=$(dirname "$f")
  ext="${f##*.}"
  base=$(basename "$f" ".$ext")

  # Read original metadata
  orig_meta=$(ffprobe -v quiet -print_format json -show_format "$f" 2>/dev/null || echo '{}')
  orig_title=$(echo "$orig_meta" | jq -r '.format.tags.title // ""')
  orig_track=$(echo "$orig_meta" | jq -r '.format.tags.track // ""')

  # A track on its own becomes a mini-album: "01 Title.mp3", "02 Title.mp3",
  # tagged 1/N, 2/N. A track inside an album keeps its place: the parts are
  # named after the original file ("03 Title 1.mp3", "03 Title 2.mp3") and keep
  # its track number, so they sort where it was and update-track-count.sh
  # renumbers the whole album in order.
  others=$(find "$dir" -maxdepth 1 -iname '*.mp3' -type f ! -path "$f" | wc -l | tr -d ' ')

  # Split into temp directory to avoid filename collisions
  split_tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/split-long-tracks.XXXXXX")
  part_durations=()
  prev_time="0"
  total_parts=$((${#split_points[@]} + 1))

  for ((p = 0; p < total_parts; p++)); do
    part_num=$((p + 1))
    padded=$(printf "%02d" "$part_num")
    if [[ "$others" -gt 0 ]]; then
      out_file="${split_tmpdir}/${base} ${part_num}.${ext}"
      part_track="${orig_track}"
    else
      out_file="${split_tmpdir}/${padded} ${orig_title:-${base}}.${ext}"
      part_track="${part_num}/${total_parts}"
    fi

    if [[ $p -lt ${#split_points[@]} ]]; then
      end_time="${split_points[$p]}"
      seg_duration=$(echo "$end_time - $prev_time" | bc -l)
    else
      end_time=""
      seg_duration=$(echo "$duration - $prev_time" | bc -l)
    fi

    # Build ffmpeg command with fade in/out
    cmd=(ffmpeg -v quiet -i "$f" -ss "$prev_time")
    if [[ -n "$end_time" ]]; then
      cmd+=(-to "$end_time")
    fi

    # Fade only at the cuts this split makes (2s in at the start of every part
    # but the first, 2s out at the end of every part but the last), and only
    # when the part is long enough (>4s) to carry both fades. The original
    # track's own start and end are left untouched.
    seg_dur_int=${seg_duration%%.*}
    seg_dur_int=${seg_dur_int:-0}
    fades=()
    if [[ $seg_dur_int -ge 4 ]]; then
      [[ $p -gt 0 ]] && fades+=("afade=t=in:st=0:d=2")
      if [[ $p -lt $((total_parts - 1)) ]]; then
        fade_out_start=$(echo "$seg_duration - 2" | bc -l)
        fades+=("afade=t=out:st=${fade_out_start}:d=2")
      fi
    fi
    if [[ ${#fades[@]} -gt 0 ]]; then
      cmd+=(-af "$(IFS=,; echo "${fades[*]}")")
    fi
    cmd+=(-c:a libmp3lame -q:a 0)
    cmd+=(-map_metadata 0)
    cmd+=(-metadata "title=${orig_title:-${base}} ${part_num}")
    [[ -n "$part_track" ]] && cmd+=(-metadata "track=${part_track}")
    cmd+=(-y "$out_file")

    if ! "${cmd[@]}" 2>/dev/null; then
      echo "Error: ffmpeg failed splitting part $part_num of $(basename "$f")" >&2
      exit 3
    fi

    part_durations+=("$(printf '%.1f' "$seg_duration")")
    prev_time="${end_time:-$duration}"
  done

  # Remove original, move splits from temp to target directory
  rm -f "$f"
  mv "${split_tmpdir}"/* "${dir}/"
  rm -rf "$split_tmpdir"

  # Build JSON for this split
  durations_json=$(printf '%s\n' "${part_durations[@]}" | jq -R 'tonumber' | jq -s '.')
  splits_json=$(echo "$splits_json" | jq \
    --arg file "$(basename "$f")" \
    --argjson parts "$total_parts" \
    --argjson durations "$durations_json" \
    '. + [{"file": $file, "parts": $parts, "durations": $durations}]')
done

jq -n --argjson splits "$splits_json" --argjson skipped "$skipped_json" \
  '{splits: $splits, skipped: $skipped}'
