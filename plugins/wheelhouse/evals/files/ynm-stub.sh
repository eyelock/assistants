#!/bin/sh
# A stand-in for ynm in the wheelhouse evals. It records every call in
# $EVAL_STUB_LOG and answers like ynm would: remember and forget succeed,
# and recall returns the contents of .eval/ynm-recall.json when a case
# set one up (otherwise no hits). Nothing reaches a real memory store.
printf '%s\n' "ynm $*" >> "$EVAL_STUB_LOG"
case "$1" in
  remember) echo '{"ok":true,"id":"01JWHEELHOUSEEVAL0000000001"}' ;;
  forget) echo '{"ok":true}' ;;
  recall | list)
    if [ -f .eval/ynm-recall.json ]; then cat .eval/ynm-recall.json; else echo '{"hits":[]}'; fi ;;
  doctor) if [ -f .eval/ynm-doctor.json ]; then cat .eval/ynm-doctor.json; else echo '{"ok":true,"checks":[]}'; fi ;;
  *) echo "(ynm $1 is stubbed in this eval; the call was recorded)" ;;
esac
