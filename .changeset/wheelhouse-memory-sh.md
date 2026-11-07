---
"@eyelock-assistants/wheelhouse": minor
---

`scripts/memory.sh`, one memory wrapper for a Wheelhouse. It reads and writes a seat's and a human's memory (identity, birth, handoff, Kudos, close notes, human notes, shared facts) with `remember`, `recall`, `forget`, `sync` and `backend`, over ynm or Beads as the `memory` key of `wheelhouse.json` says. With no file or no key it runs the ynm commands the skills always gave. Both backends answer `recall` in the same JSON, `[{id, kind, text, at, by, bead}]`, newest first, and a failing store is an error, never an empty answer. With Beads the key layout (`seat/<command>/...`, `human/<command>/note/...`, `wheelhouse/<slug>`) lives only in the script, and `sync` reports memory and work as one result. The evals gain `install_beads_memory` for a Beads-memory Wheelhouse.
