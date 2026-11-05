---
"@eyelock-assistants/wheelhouse": minor
---

The `work-graph` skill ships `scripts/open-pr.sh`, the one way a worker opens a pull request. It reads the bead's `external_ref`, resolves the tracker item and its release through the Wheelhouse's `tracker.json`, opens a draft pull request with the release set (a milestone on GitHub), and writes the tracker's own closing link: on GitHub, `Closes #N` when the bead is the last open bead on the issue and `Part of #N` otherwise. It refuses, saying why, a bead with no tracker item unless it is labelled `housekeeping`, a reference that doesn't match the config's pattern, and an item with no release; with no tracker it still opens pull requests. The tracker adapter is `tracker-<kind>.sh`: `tracker-github.sh` holds everything GitHub-specific, and `tracker-generic.sh` serves any other kind until it gets its own. The worker and specialist-worker templates say to open pull requests only with the script.
