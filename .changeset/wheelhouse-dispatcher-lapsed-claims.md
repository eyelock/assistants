---
"@eyelock-assistants/wheelhouse": minor
---

The dispatcher looks for lapsed claims at each check-in. The `work-graph` skill gains a "Checking in for lapsed claims" section (list beads in progress, set aside live leases and open pull requests, confirm the holder is gone, then reclaim), and the dispatcher template says to do it each time it wakes. A merged bead the worker still holds is closed by reclaiming it first and then `bd close` (the dispatcher never uses `--force`), and the section reads the lease from `bd show --json`.
