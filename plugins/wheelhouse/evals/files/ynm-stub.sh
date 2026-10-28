#!/bin/sh
# A stand-in for ynm in the wheelhouse evals. It records every call in
# $EVAL_STUB_LOG and answers like ynm would: remember and forget succeed,
# and recall returns .eval/ynm-recall-<tag>.json for a recall tagged identity,
# handoff, kudos or birth, and .eval/ynm-recall.json for any other, when a case
# set one up (otherwise no hits). pin succeeds. Nothing reaches a real memory store.
printf '%s\n' "ynm $*" >> "$EVAL_STUB_LOG"
case "$1" in
  remember) echo 'remembered 01JWHEELHOUSEEVAL0000000001 in project' ;;
  forget | pin) echo '{"ok":true}' ;;
  recall | list)
    f=.eval/ynm-recall.json
    for tag in identity handoff kudos birth; do
      case " $* " in *" $tag "* | *"=$tag "* | *",$tag"* | *"$tag,"*)
        [ -f ".eval/ynm-recall-$tag.json" ] && f=".eval/ynm-recall-$tag.json" ;;
      esac
    done
    if [ -f "$f" ]; then cat "$f"; else echo '[]'; fi ;;
  doctor) if [ -f .eval/ynm-doctor.json ]; then cat .eval/ynm-doctor.json; else echo '{"ok":true,"checks":[]}'; fi ;;
  *) echo "(ynm $1 is stubbed in this eval; the call was recorded)" ;;
esac
