#!/usr/bin/env bash
# patrol reap, control: the same Wheelhouse as patrol-reap.sh with the CI watcher's charter missing
# its Reaping section. The case's "baseline_setup", so the without_skill arm removes the text
# under test, which the case's own setup would otherwise leave in place.
set -euo pipefail
export REAP_CONTROL=1
. "$EVAL_FIXTURES/patrol-reap.sh"
