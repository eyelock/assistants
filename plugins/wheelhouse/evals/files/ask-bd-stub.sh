#!/usr/bin/env bash
# A small stateful stand-in for bd, for ask.sh's tests: beads live in $BD_STORE (a JSON file
# {beads: [...], edges: [{from, to}]}, where `from` blocks `to`; dep list <id> --direction up lists what `id` blocks). It understands only what
# ask.sh calls: create, show, update, comments add, list and dep list. $BD_NOW (an ISO time)
# stamps new beads, and $BD_LOG records every call.
set -uo pipefail
store="${BD_STORE:?}"
[ -f "$store" ] || echo '{"beads":[],"edges":[]}' >"$store"
echo "bd $*" >>"${BD_LOG:-/dev/null}"
sub="${1:-}"; shift || true
save() { jq -c "$1" "$store" >"$store.new" && mv "$store.new" "$store"; }
case "$sub" in
  create)
    labels='[]'; actor=""; assignee=""; title=""; desc=""; prio=2; deps=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --title) title="$2"; shift 2 ;; --actor) actor="$2"; shift 2 ;; --assignee) assignee="$2"; shift 2 ;;
        --labels) labels=$(jq -c --arg l "$2" '. + [$l]' <<<"$labels"); shift 2 ;;
        --description) desc="$2"; shift 2 ;; --priority) prio="$2"; shift 2 ;; --deps) deps="$2"; shift 2 ;;
        --json) shift ;; *) shift ;;
      esac
    done
    n=$(jq '.beads | length' "$store"); id="hq-$((n + 100))"
    jq -c --arg id "$id" --arg t "$title" --arg a "$actor" --arg as "$assignee" --arg d "$desc" --argjson p "$prio" \
      --argjson l "$labels" --arg now "${BD_NOW:-2026-11-10T12:00:00Z}" \
      '.beads += [{id: $id, title: $t, description: $d, status: "open", priority: $p, created_by: $a, assignee: $as, labels: $l, created_at: $now, comments: []}]' \
      "$store" >"$store.new" && mv "$store.new" "$store"
    case "$deps" in blocks:*) jq -c --arg f "$id" --arg t "${deps#blocks:}" '.edges += [{from: $f, to: $t}]' "$store" >"$store.new" && mv "$store.new" "$store" ;; esac
    jq -c --arg id "$id" '.beads[] | select(.id == $id)' "$store"
    ;;
  show)
    id="$1"
    jq -e --arg id "$id" '.beads[] | select(.id == $id)' "$store" >/dev/null || { echo "no issue $id" >&2; exit 1; }
    jq -c --arg id "$id" '[.beads[] | select(.id == $id)]' "$store"
    ;;
  update)
    id="$1"; shift
    jq -e --arg id "$id" '.beads[] | select(.id == $id)' "$store" >/dev/null || { echo "no issue $id" >&2; exit 1; }
    assignee=""; has_assignee=0; status=""; add='[]'; rm='[]'; guard=""; has_guard=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --assignee) assignee="$2"; has_assignee=1; shift 2 ;; --status) status="$2"; shift 2 ;;
        --add-label) add=$(jq -c --arg l "$2" '. + [$l]' <<<"$add"); shift 2 ;;
        --remove-label) rm=$(jq -c --arg l "$2" '. + [$l]' <<<"$rm"); shift 2 ;;
        --if-assignee) guard="$2"; has_guard=1; shift 2 ;; --actor) shift 2 ;; *) shift ;;
      esac
    done
    if [ "$has_guard" = 1 ]; then
      cur=$(jq -r --arg id "$id" '.beads[] | select(.id == $id) | .assignee // ""' "$store")
      [ "$cur" = "$guard" ] || { echo "assignee mismatch" >&2; exit 13; }
    fi
    jq -c --arg id "$id" --arg a "$assignee" --argjson ha "$has_assignee" --arg s "$status" --argjson add "$add" --argjson rm "$rm" \
      '.beads |= map(if .id == $id then
          (if $ha == 1 then .assignee = $a else . end)
          | (if $s != "" then .status = $s else . end)
          | .labels = (((.labels + $add) | unique) - $rm) else . end)' "$store" >"$store.new" && mv "$store.new" "$store"
    echo "updated $id"
    ;;
  comments)
    [ "${1:-}" = add ] || exit 1
    id="$2"; body="$3"
    jq -e --arg id "$id" '.beads[] | select(.id == $id)' "$store" >/dev/null || { echo "no issue $id" >&2; exit 1; }
    jq -c --arg id "$id" --arg b "$body" '.beads |= map(if .id == $id then .comments += [$b] else . end)' "$store" >"$store.new" && mv "$store.new" "$store"
    echo "commented on $id"
    ;;
  list)
    label=""; statuses=""; assignee=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --label) label="$2"; shift 2 ;; --status) statuses="$2"; shift 2 ;; --assignee) assignee="$2"; shift 2 ;; *) shift ;;
      esac
    done
    jq -c --arg l "$label" --arg s "$statuses" --arg a "$assignee" \
      '[.beads[] | select(($l == "" or (.labels | index($l)))
          and ($s == "" or (.status as $st | ($s | split(",")) | index($st)))
          and ($a == "" or .assignee == $a))]' "$store"
    ;;
  dep)
    [ "${1:-}" = list ] || exit 1
    id="$2"
    jq -c --arg id "$id" '[.edges[] | select(.from == $id) | {id: .to, dependency_type: "blocks"}]' "$store"
    ;;
  *) echo "stub bd: unsupported: $sub" >&2; exit 1 ;;
esac
