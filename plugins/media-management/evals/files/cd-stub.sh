#!/usr/bin/env bash
# Stand-in for the optical drive and the web in the media-management eval
# sandboxes: installed as cd-paranoia, drutil, diskutil and curl (sandbox.sh's
# install_cd_stubs), it plays whichever tool it is called as, from the model
# in .eval/cd/ (which disc is in the drive) and the canned responses in
# .eval/web/ (built by cd-fixture.py). Every call is logged, labelled, to
# $EVAL_STUB_LOG. The rip is real WAV audio, so checksums and encodes work.
#
# Exit codes: as the real tool would give for the same situation.
set -uo pipefail

state="$(cd "$(dirname "$0")/.." && pwd)"
cd_state="$state/cd"
web="$state/web"
log="${EVAL_STUB_LOG:-$state/stub-calls.log}"
tool=$(basename "$0")
disc=$(cat "$cd_state/disc" 2>/dev/null || echo none)

{
  printf '%s [disc %s]' "$tool" "$disc"
  for a in "$@"; do printf ' %q' "$a"; done
  printf '\n'
} >>"$log"

fixture() {
  python3 -I "$cd_state/cd-fixture.py" "$@"
}

case "$tool" in
  drutil)
    case "${1:-}" in
      status)
        echo " Vendor   Product           Rev "
        echo " STUBCORP BDDVDW SE-506CB   TS01"
        echo
        if [[ "$disc" == none ]]; then
          echo "           Type: No Media Inserted"
        else
          echo "           Type: CD-ROM               Name: /dev/disk9"
        fi
        ;;
      eject)
        echo none >"$cd_state/disc"
        ;;
      *) exit 0 ;;
    esac
    ;;

  diskutil)
    case "${1:-}" in
      unmountDisk) echo "Unmount of all volumes on ${2:-disk} was successful" ;;
      mountDisk) echo "Volume(s) mounted successfully" ;;
      *) echo "diskutil stub: ${1:-} not modelled" >&2; exit 1 ;;
    esac
    ;;

  cd-paranoia)
    if [[ "${1:-}" == "--version" ]]; then
      echo "cdparanoia III release 10.2 (stub)" >&2
      exit 0
    fi
    if [[ "$disc" == none ]]; then
      echo "Unable to open disc.  Is there an audio CD in the drive?" >&2
      exit 1
    fi
    offset=0
    track=""
    out=""
    query=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -Q | --query) query=true; shift ;;
        -d | -O)
          [[ "$1" == -O ]] && offset="$2"
          shift 2
          ;;
        -w)
          track="$2"
          out="$3"
          shift 3
          ;;
        *) shift ;;
      esac
    done
    if [[ "$query" == true ]]; then
      fixture toc "$disc"
      exit 0
    fi
    if [[ -z "$track" || -z "$out" ]]; then
      echo "cd-paranoia stub: expected -w <track> <file>" >&2
      exit 1
    fi
    echo "Ripping from sector ... (track $track)" >&2
    fixture audio "$disc" "$track" "$out" --offset "$offset" || exit 1
    echo "Done." >&2
    ;;

  curl)
    out=""
    fmt=""
    url=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -o) out="$2"; shift 2 ;;
        -w) fmt="$2"; shift 2 ;;
        -A | -H | --max-time) shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
      esac
    done
    path="${url#*://}"
    body=""
    case "$path" in
      musicbrainz.org/ws/2/discid/-\?*) body="" ;;
      musicbrainz.org/ws/2/discid/*)
        id="${path#musicbrainz.org/ws/2/discid/}"
        body="$web/mb-discid-${id%%\?*}.json"
        ;;
      musicbrainz.org/ws/2/release\?* | musicbrainz.org/ws/2/release/\?*)
        # A search: Night Drive's releases only.
        case "$url" in
          *[Nn]ight*[Dd]rive* | *[Aa]fterglow*) body="$web/mb-search.json" ;;
          *) body="$web/mb-search-empty.json" ;;
        esac
        ;;
      musicbrainz.org/ws/2/release/*)
        id="${path#musicbrainz.org/ws/2/release/}"
        body="$web/mb-release-${id%%\?*}.json"
        ;;
      www.accuraterip.com/accuraterip/*) body="$web/$(basename "$path")" ;;
      coverartarchive.org/release/*/front*)
        id="${path#coverartarchive.org/release/}"
        body="$web/cover-${id%%/*}.jpg"
        ;;
    esac
    code=404
    if [[ -n "$body" && -f "$body" ]]; then
      code=200
      if [[ -n "$out" ]]; then cp "$body" "$out"; else cat "$body"; fi
    elif [[ -n "$out" ]]; then
      echo '{"error": "Not Found"}' >"$out"
    fi
    [[ -n "$fmt" ]] && printf '%s' "${fmt//%\{http_code\}/$code}"
    exit 0
    ;;

  *)
    echo "cd-stub: called as unknown tool $tool" >&2
    exit 1
    ;;
esac
