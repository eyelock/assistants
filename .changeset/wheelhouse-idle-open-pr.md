---
"@eyelock-assistants/wheelhouse": patch
---

Who is idle: a worker whose only in-progress beads have open pull requests is free for new work, and the dispatcher's May-not and Dispatching step 7 agree it may be given a new bead. `open-pr.sh` notes each pull request on its bead as `PR: <url>`, the one signal the idle check, the wake and the never-a-dead-claim rule read; the wake marks an in-progress bead "(waiting on PR <url>)" when its pull request is open. A bead with no pull request closes when its worker has handed the work over. Adds a dispatch eval, and tests for the note and the wake mark.
