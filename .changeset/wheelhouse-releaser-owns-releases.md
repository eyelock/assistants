---
"@eyelock-assistants/wheelhouse": minor
---

The releaser owns every release and each milestone's release readiness. Its starter template now covers every tag, release pull request, check, back-merge and publish (still never publishing or merging without the human), keeps one live readiness record per milestone and answers "can we release?" with a go or no-go. It also documents the permission allow rule a human adds so the releaser's tag push is not blocked by the auto-mode classifier. The dispatcher template and the work-graph skill say a release bead is never handed to a worker: it stays unassigned and goes to the desk, which routes it to the releaser.
