#!/usr/bin/env bash
# inbox wake, broken: the empty inbox world, but the humans' inbox can't be
# read: bd's database is locked for `bd ready --assignee` of a human, and ynm
# can't reach its store for a recall in a human's namespace. Everything else
# (the seat's own wake, the evidence) still works, so the eval shows whether
# the desk says the inbox couldn't be read rather than that nothing is waiting.
set -euo pipefail
bash "$EVAL_FIXTURES/inbox-wake.sh" pat@example.com empty

real_bd=$(command -v bd)
cat > "$EVAL_BIN/bd" <<SH
#!/bin/sh
if [ "\$1" = ready ]; then
  case " \$* " in *" --assignee rook "* | *" --assignee pat "*)
    echo "Error: database is locked" >&2; exit 1 ;;
  esac
fi
exec "$real_bd" "\$@"
SH
chmod +x "$EVAL_BIN/bd"

mv "$EVAL_BIN/ynm" "$EVAL_BIN/ynm-answers"
cat > "$EVAL_BIN/ynm" <<SH
#!/bin/sh
if [ "\$1" = recall ]; then
  case " \$* " in *" --namespace human/"*)
    printf '%s\n' "ynm \$*" >> "\$EVAL_STUB_LOG"
    echo "ynm: cannot reach the memory store" >&2; exit 1 ;;
  esac
fi
exec "$EVAL_BIN/ynm-answers" "\$@"
SH
chmod +x "$EVAL_BIN/ynm"
