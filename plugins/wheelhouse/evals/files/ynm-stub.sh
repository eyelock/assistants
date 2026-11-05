#!/bin/sh
# A stand-in for ynm in the wheelhouse evals. It records every call in
# $EVAL_STUB_LOG and answers like ynm would. remember stores the memory in
# .eval/ynm-store.jsonl with an id of its own, so a seat can recall what it
# just wrote. recall returns the case's .eval/ynm-recall-<tag>.json for a recall
# tagged identity, handoff, kudos or birth (.eval/ynm-recall.json for any
# other), when the case set one up, plus what this run remembered with that
# tag, keeping only the asked namespace's and tag's memories, as ynm does. init
# writes .ynm/config.json; pin and forget succeed. Nothing reaches a real memory store.
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
  # Like ynm, init writes the repository's config, .ynm/config.json.
  init)
    mkdir -p .ynm
    [ -f .ynm/config.json ] || printf '{\n  "anchor": "0000000"\n}\n' > .ynm/config.json
    echo "initialised project mount in $PWD" ;;
  forget | pin) echo '{"ok":true}' ;;
  recall | list)
    want=$(flag tags "$@")
    # One file per tag the recall asks for (a recall may ask for several,
    # comma-separated), else .eval/ynm-recall.json.
    files=""
    for tag in identity handoff kudos birth; do
      case ",$want," in *",$tag,"*)
        [ -f ".eval/ynm-recall-$tag.json" ] && files="$files .eval/ynm-recall-$tag.json" ;;
      esac
    done
    [ -n "$files" ] || { [ -f .eval/ynm-recall.json ] && files=.eval/ynm-recall.json; }
    ns=$(flag namespace "$@")
    base='[]'
    # shellcheck disable=SC2086
    [ -n "$files" ] && base=$(jq -cs 'add' $files)
    mine='[]'
    [ -f "$store" ] && mine=$(jq -cs --arg t "$want" 'map(select($t == "" or (.tags as $have | $t | split(",") | any(. as $w | $have | index($w)))))' "$store")
    # Like ynm, a recall in a namespace returns only that namespace's memories.
    jq -cn --argjson a "$base" --argjson b "$mine" --arg ns "$ns" --arg t "$want" \
      '($b + $a) | map(select(($ns == "" or .namespace == null or .namespace == $ns)
        and ($t == "" or .tags == null or (.tags as $have | $t | split(",") | any(. as $w | $have | index($w))))))' ;;
  doctor) if [ -f .eval/ynm-doctor.json ]; then cat .eval/ynm-doctor.json; else echo '{"ok":true,"checks":[]}'; fi ;;
  --help | -h | help) echo "ynm: shared memory for agents. Commands: remember, recall, pin, forget, context, doctor, init, sync." ;;
  *) echo '{"ok":true}' ;;
esac
