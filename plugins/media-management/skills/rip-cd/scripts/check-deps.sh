#!/usr/bin/env bash
# Check the command-line tools CD ripping needs, and say how to install any
# that are missing.
# Usage: check-deps.sh
# Output: JSON to stdout
# Exit codes: 0=all present, 3=something missing

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: check-deps.sh

Check that every tool the rip-cd skill runs is installed and runs (each is
asked for its version): cd-paranoia (secure
ripping), ffmpeg/ffprobe (encoding and tags), python3 (disc IDs and
AccurateRip checksums), curl (MusicBrainz, AccurateRip and cover art lookups)
and jq. Takes no arguments.

Output: JSON to stdout
  {
    "ok": false,
    "tools": [{"tool": "cd-paranoia", "found": false, "path": null,
               "install": "brew install libcdio-paranoia"}, ...],
    "missing": ["cd-paranoia"],
    "install_command": "brew install libcdio-paranoia"
  }

Exit codes:
  0  Every tool is installed
  3  At least one tool is missing or will not run (see "missing" and
     "install_command": "brew reinstall" for a tool that is there but broken)
HELP
}

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
  esac
done

# tool:brew formula that provides it:the flag that makes it print its version
TOOLS=(
  "cd-paranoia:libcdio-paranoia:--version"
  "ffmpeg:ffmpeg:-version"
  "ffprobe:ffmpeg:-version"
  "python3:python:--version"
  "curl:curl:--version"
  "jq:jq:--version"
)

# jq itself may be the missing tool, so the JSON is built by hand.
entries=()
missing=()
formulas=()
for entry in "${TOOLS[@]}"; do
  IFS=: read -r tool formula version_flag <<<"$entry"
  # Found AND runs: a broken install (a missing library after an upgrade)
  # counts as missing.
  if path=$(command -v "$tool" 2>/dev/null) && "$tool" "$version_flag" >/dev/null 2>&1; then
    entries+=("{\"tool\": \"$tool\", \"found\": true, \"path\": \"$path\", \"install\": \"brew install $formula\"}")
  else
    verb=install
    # Installed but will not run: reinstalling brings back what it lost.
    command -v "$tool" &>/dev/null && verb=reinstall
    entries+=("{\"tool\": \"$tool\", \"found\": false, \"path\": null, \"install\": \"brew $verb $formula\"}")
    missing+=("\"$tool\"")
    case " ${formulas[*]:-} " in
      *" $verb:$formula "*) ;;
      *) formulas+=("$verb:$formula") ;;
    esac
    echo "Missing: $tool (brew $verb $formula)" >&2
  fi
done

# ffmpeg builds without LAME cannot write MP3s.
if command -v ffmpeg &>/dev/null && ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libmp3lame; then
  entries+=("{\"tool\": \"libmp3lame\", \"found\": false, \"path\": null, \"install\": \"brew reinstall ffmpeg\"}")
  missing+=("\"libmp3lame\"")
  echo "Missing: ffmpeg was built without libmp3lame" >&2
fi

join() {
  local IFS=,
  echo "$*"
}

ok=true
install=null
if [[ ${#missing[@]} -gt 0 ]]; then
  ok=false
  # One command per verb: "brew install a b && brew reinstall c".
  cmds=()
  for verb in install reinstall; do
    names=()
    for f in "${formulas[@]:-}"; do
      [[ "$f" == "$verb:"* ]] && names+=("${f#*:}")
    done
    [[ ${#names[@]} -gt 0 ]] && cmds+=("brew $verb ${names[*]}")
  done
  if [[ ${#cmds[@]} -gt 0 ]]; then
    joined="${cmds[0]}"
    [[ ${#cmds[@]} -gt 1 ]] && joined="$joined \u0026\u0026 ${cmds[1]}"
    install="\"$joined\""
  fi
fi

printf '{"ok": %s, "tools": [%s], "missing": [%s], "install_command": %s}\n' \
  "$ok" "$(join "${entries[@]}")" "$(join "${missing[@]:-}")" "$install"

[[ "$ok" == true ]] || exit 3
