#!/usr/bin/env bash
# birth memory-unreadable: McCoist's session, but ynm can't reach its store, so a recall in any
# namespace fails (rather than answering with nothing). The wake says memory couldn't be read.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
team_wheelhouse
release_graph >/dev/null

mv "$EVAL_BIN/ynm" "$EVAL_BIN/ynm-answers"
cat > "$EVAL_BIN/ynm" <<SH
#!/bin/sh
if [ "\$1" = recall ]; then
  printf '%s\n' "ynm \$*" >> "\$EVAL_STUB_LOG"
  echo "ynm: cannot reach the memory store" >&2; exit 1
fi
exec "$EVAL_BIN/ynm-answers" "\$@"
SH
chmod +x "$EVAL_BIN/ynm"
