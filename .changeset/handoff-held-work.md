---
"@eyelock-assistants/wheelhouse": minor
---

The handoff skill lists only what the seat can act on next. Work that is held (a pull request waiting on a design, a decision or another merge) is recorded in the work graph as a bead blocked by what it waits on (`bd dep add <held-id> --blocked-by <waits-on-id>`), so it leaves `bd ready` and returns when that closes, and the handoff points to it by id instead of copying it forward, so the next wake no longer re-reads or re-sorts it (assistants #255). The skill's notes template gains a **Held** line of ids only, and a new eval, `take-a-beat-held-work`, covers a handoff with held work.
