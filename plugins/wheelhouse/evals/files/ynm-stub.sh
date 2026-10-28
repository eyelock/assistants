#!/bin/sh
# A stand-in for ynm in the wheelhouse evals. It records every call in
# $EVAL_STUB_LOG and answers like ynm would. remember stores the memory in
# .eval/ynm-store.jsonl with an id of its own, so a seat can recall what it
# just wrote. recall returns the case's .eval/ynm-recall-<tag>.json for a recall
# tagged identity, handoff, kudos or birth (.eval/ynm-recall.json for any
# other), when the case set one up, plus what this run remembered with that
# tag. pin and forget succeed. Nothing reaches a real memory store.
printf '%s\n' "ynm $*" >> "$EVAL_STUB_LOG"
store=.eval/ynm-store.jsonl
mkdir -p .eval

# The values of the flags a call gives, as --flag value or --flag=value.
flag() {
  name=$1; shift
  while [ $# -gt 0 ]; do
    case "$1" in
      "--$name") printf '%s' "$2"; return ;;
      "--$name="*) printf '%s' "${1#--$name=}"; return ;;
    esac
    shift
  done
}

case "$1" in
  remember)
    n=$(( $( [ -f "$store" ] && wc -l < "$store" || echo 0 ) + 1 ))
    id=$(printf '01JWHEELHOUSEEVAL%09d' "$n")
    shift
    jq -cn --arg id "$id" --arg ns "$(flag namespace "$@")" --arg subject "$(flag subject "$@")" \
      --arg tags "$(flag tags "$@")" --arg type "$(flag type "$@")" --arg content "$(flag content "$@")" \
      '{memoryId: $id, namespace: $ns, subject: $subject, type: $type, tags: ($tags | split(",")), content: $content, pinned: false}' >> "$store"
    echo "remembered $id in project" ;;
  forget | pin) echo '{"ok":true}' ;;
  recall | list)
    f=.eval/ynm-recall.json
    want=$(flag tags "$@")
    for tag in identity handoff kudos birth; do
      case " $* " in *" $tag "* | *"=$tag "* | *",$tag"* | *"$tag,"*)
        [ -f ".eval/ynm-recall-$tag.json" ] && f=".eval/ynm-recall-$tag.json" ;;
      esac
    done
    base='[]'
    [ -f "$f" ] && base=$(cat "$f")
    mine='[]'
    [ -f "$store" ] && mine=$(jq -cs --arg t "$want" 'map(select($t == "" or (.tags | index($t))))' "$store")
    jq -cn --argjson a "$base" --argjson b "$mine" '$b + $a' ;;
  doctor) if [ -f .eval/ynm-doctor.json ]; then cat .eval/ynm-doctor.json; else echo '{"ok":true,"checks":[]}'; fi ;;
  --help | -h | help) echo "ynm: shared memory for agents. Commands: remember, recall, pin, forget, context, doctor, init, sync." ;;
  *) echo '{"ok":true}' ;;
esac
