---
"@eyelock-assistants/wheelhouse": patch
---

`wake.sh --end --no-sync` no longer syncs: it skips both the memory sync (`ynm sync`) and the work graph sync (`bd sync`), as `--no-sync` does at wake, and reports both as `skipped`.
