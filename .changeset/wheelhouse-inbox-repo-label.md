---
"@eyelock-assistants/wheelhouse": patch
---

Inbox beads name their repository, as every task does. `inbox.sh assign` takes `--repo <repo>` and labels the bead `repo:<repo>`; without it, the bead takes the `repo:` label of the bead it blocks. A merge or review is refused without a repository; a decision or credential that touches none goes unlabelled, and the work-graph skill says so.
