---
"@eyelock-assistants/wheelhouse": patch
---

Who is idle: a worker whose only in-progress beads have open pull requests is free for new work, and a worker notes the pull request's URL on the bead. A bead with no pull request closes when its worker has handed the work over. Adds a dispatch eval for it.

`open-pr.sh` now notes the pull request on the bead as `PR: <url>`, the one signal the idle check, the wake and the dead-claim check read; the wake marks an in-progress bead "(waiting on PR <url>)" when its pull request is open; the dispatcher's May-not and step 7 agree a worker whose pull requests are open may be given a new bead.
