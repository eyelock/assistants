#!/usr/bin/env bash
# Prints what a media-management eval run left behind, for the judge: every
# file added, removed or changed since setup, the whole tree, the tags of every
# MP3 (as ffprobe reads them), the plugin's config.json, and the playlists the
# Apple Music stub holds. Run from the run's directory.
#
#   evidence.sh             the report
#   evidence.sh --manifest  checksums of every file (setup's snapshot)
#
# The sandbox's own plumbing (.eval/, .claude/) is left out.
# Exit codes: 0 success.
set -uo pipefail

files() {
  find . -type f -not -path './.eval/*' -not -path './.claude/*' | LC_ALL=C sort
}

manifest() {
  files | while IFS= read -r f; do
    printf '%s\t%s\n' "$(cksum <"$f" | tr -s ' ' '-')" "$f"
  done
}

if [[ "${1:-}" == "--manifest" ]]; then
  manifest
  exit 0
fi

echo "== Changes since setup (+ added, - removed, ~ changed) =="
if [[ -f .eval/before.txt ]]; then
  manifest >.eval/after.txt
  changes=$(awk -F '\t' '
    NR == FNR { before[$2] = $1; next }
    { after[$2] = $1 }
    END {
      for (p in before) if (!(p in after)) print "- " p
      for (p in after) if (!(p in before)) print "+ " p
      for (p in after) if ((p in before) && before[p] != after[p]) print "~ " p
    }' .eval/before.txt .eval/after.txt | LC_ALL=C sort -k2)
  echo "${changes:-(no files changed)}"
else
  echo "(no snapshot)"
fi
echo

echo "== Files =="
files | while IFS= read -r f; do
  printf '%10s  %s\n' "$(wc -c <"$f" | tr -d ' ')" "$f"
done
echo

mp3s=$(files | grep -i '\.mp3$' || true)
if [[ -n "$mp3s" ]]; then
  echo "== MP3 tags (file | title | artist | album | album_artist | genre | track | compilation | duration) =="
  while IFS= read -r f; do
    json=$(ffprobe -v quiet -print_format json -show_format "$f" 2>/dev/null || echo '{}')
    jq -r --arg f "$f" '.format as $x | ($x.tags // {}) as $t |
      [$f, $t.title, $t.artist, $t.album, ($t.album_artist // $t.TPE2), $t.genre, $t.track,
       ($t.compilation // $t.TCMP), (($x.duration // "0") | tonumber | floor | tostring) + "s"]
      | map(. // "-") | join(" | ")' <<<"$json"
  done <<<"$mp3s"
  echo
fi

config=$(jq -r '.env.MEDIA_MGMT_CONFIG_PATH // empty' .claude/settings.json 2>/dev/null)
if [[ -n "$config" ]]; then
  echo "== config.json ($config) =="
  if [[ -f "$config" ]]; then cat "$config"; else echo "(does not exist)"; fi
  echo
fi

if [[ -f .eval/music/playlists ]]; then
  echo "== Apple Music stub: user playlists (name, tracks) =="
  if [[ -s .eval/music/playlists ]]; then cat .eval/music/playlists; else echo "(none)"; fi
fi
