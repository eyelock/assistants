#!/usr/bin/env bash
# Copy MP3 files to Apple Music auto-import folder.
# Usage: import-mp3s.sh <source_folder> <import_folder>
# Output: JSON to stdout with copy results
# Exit codes: 0=success, 1=bad args, 2=folder not found, 3=copy error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: import-mp3s.sh <source_folder> <import_folder>

Copy all MP3 files from source folder to the Apple Music auto-import folder.

Arguments:
  source_folder   Path to folder containing MP3 files
  import_folder   Path to Apple Music auto-import folder
  --help          Show this help

Output: JSON to stdout
  {
    "source_folder": "/path/to/source",
    "import_folder": "/path/to/import",
    "files_copied": 8,
    "files": ["01 Track.mp3", "02 Track.mp3", ...]
  }

Exit codes:
  0  Success
  1  Bad arguments
  2  Source or import folder not found
  3  Copy error
HELP
}

SOURCE=""
IMPORT=""

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *)
      if [[ -z "$SOURCE" ]]; then
        SOURCE="$arg"
      elif [[ -z "$IMPORT" ]]; then
        IMPORT="$arg"
      fi
      ;;
  esac
done

if [[ -z "$SOURCE" || -z "$IMPORT" ]]; then
  echo "Error: both source_folder and import_folder arguments required" >&2
  show_help >&2
  exit 1
fi

if [[ ! -d "$SOURCE" ]]; then
  echo "Error: source folder not found: $SOURCE" >&2
  exit 2
fi

if [[ ! -d "$IMPORT" ]]; then
  echo "Error: import folder not found: $IMPORT" >&2
  echo "Hint: Apple Music auto-import folder may need to be created or located" >&2
  exit 2
fi

# Find MP3 files
files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$SOURCE" -maxdepth 1 -iname '*.mp3' -type f | sort)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Error: no MP3 files found in $SOURCE" >&2
  exit 1
fi

# Copy each file
copied_files="[]"
copy_count=0
errors=0

for f in "${files[@]}"; do
  filename=$(basename "$f")
  if cp "$f" "$IMPORT/" 2>/dev/null; then
    copied_files=$(echo "$copied_files" | jq --arg name "$filename" '. + [$name]')
    copy_count=$((copy_count + 1))
    echo "Copied: $filename" >&2
  else
    echo "Error copying: $filename" >&2
    errors=$((errors + 1))
  fi
done

if [[ $copy_count -eq 0 ]]; then
  echo "Error: no files were copied successfully" >&2
  exit 3
fi

if [[ $errors -gt 0 ]]; then
  echo "Warning: $errors file(s) failed to copy" >&2
fi

jq -n \
  --arg source_folder "$SOURCE" \
  --arg import_folder "$IMPORT" \
  --argjson files_copied "$copy_count" \
  --argjson files "$copied_files" \
  '{source_folder: $source_folder, import_folder: $import_folder, files_copied: $files_copied, files: $files}'
