---
"@eyelock-assistants/wheelhouse": minor
---

The patrol flags a stalled draft. A new `pr-stalled` change reports a draft pull request that is green on CI and whose last commit is older than `--stale-after` minutes (default 30) and newer than its last review, or that has no review, so the CI watcher can tell the desk to send it to review.
