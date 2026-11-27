---
"@eyelock-assistants/wheelhouse": patch
---

`limited()` in `wheelhouse-lib.sh` now follows SIGTERM with SIGKILL to the command's process group after a short grace (`WL_KILL_GRACE`, 2 seconds) before it exits 142. Before, a timed-out `bd sync` that survived SIGTERM was orphaned and kept holding Dolt's lock, so every later `bd` call failed until someone killed it by hand. A new eval runs a TERM-ignoring child and checks nothing outlives the limit.
