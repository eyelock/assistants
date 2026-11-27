---
"@eyelock-assistants/wheelhouse": patch
---

`limited()` in `wheelhouse-lib.sh` now follows SIGTERM with SIGKILL to the command's process group after a short grace (`WL_KILL_GRACE`, 2 seconds) before it exits 142. Before, a timed-out `bd sync` that survived SIGTERM was orphaned and kept holding Dolt's lock, so every later `bd` call failed until someone killed it by hand. A new eval runs a TERM-ignoring child and checks nothing outlives the limit.

The timer now sits in a process group of its own, so killing the caller's group (the session-end hook's timeout, Ctrl-C) no longer leaves the command running with no limit: the timer still kills and reaps it at the alarm. `wake.sh --end` counts the grace in its budget, so a budget of 28 seconds stays 28 in all and the 30-second hook is never hit.
