---
"@eyelock-assistants/wheelhouse": patch
---

Seat evals get recording and refusing stubs for `gh`, `git` and `bd` (`seat-stub.sh`) and a test-Wheelhouse fixture (`seat-fixture.sh`) under `plugins/wheelhouse/evals/files/`. Each stub logs every call as one `<command> <arguments>` line and refuses what the case forbids; `git` also refuses `stash` anywhere and `checkout`, `switch`, `reset` and `commit` in a shared checkout. Tests are in `seat-stubs.test.mjs`.
