---
"@eyelock-assistants/wheelhouse": patch
---

Seat evals get recording and refusing stubs for `gh`, `git` and `bd` (`seat-stub.sh`) and a test-Wheelhouse fixture (`seat-fixture.sh`) under `plugins/wheelhouse/evals/files/`. Each stub logs every call as one `<command> <arguments>` line and refuses what the case forbids; `git` also refuses `stash` anywhere and `checkout`, `switch`, `reset`, `commit`, `merge`, `pull` and `rebase` in a shared checkout, found through `-C`, `--git-dir`, `--work-tree`, `GIT_DIR` and `GIT_WORK_TREE` as well as the directory. Tests are in `seat-stubs.test.mjs`.
