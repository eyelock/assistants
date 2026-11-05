#!/usr/bin/env bash
# doctor unborn: a Wheelhouse set up right, except that one worker, Dalglish,
# was seated but never born: no identity is pinned in seat/dalglish.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
specialist_wheelhouse Dalglish=repo:ynh Strachan
jq 'map(select(.namespace != "seat/dalglish"))' .eval/ynm-recall-identity.json > .eval/i.json && mv .eval/i.json .eval/ynm-recall-identity.json
ynm_doctor ok registered ok
