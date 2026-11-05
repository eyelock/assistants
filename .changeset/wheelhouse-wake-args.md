---
"@eyelock-assistants/wheelhouse": patch
---

The wake skill gives a path that resolves for a seat the desk wakes as a subagent: the Wheelhouse's own `scripts/wake.sh`, run from its root, or by its full path with `--dir <wheelhouse>` from anywhere, with the exact `--seat <command>` form. It no longer says `path/to/wake/scripts/wake.sh`. `wake.sh` takes the seat's name bare as well (`wake.sh hynde`), refuses two different seats or two bare names with usage, and, when it can't tell which seat it is, stops with usage and the roster's seats. The seat is not guessed from the harness: nothing a running seat can read names it reliably.
