---
"@eyelock-assistants/wheelhouse": minor
---

The tracker config takes `exempt_repos`: a list of repository names that are exempt from the tracker, such as a Wheelhouse's own repository when it plans in beads. A bead whose `repo:` label is on the list needs no issue: `open-pr.sh` opens its pull request with no item, no closing link and no milestone (its output says `"exempt": true`), whatever the bead's `external_ref` says, and the dispatcher's note has no tracker line. The check comes before any adapter is called, so it holds for every tracker kind, and an `exempt_repos` that is not a list of strings is a fault. A bead in any other repository is unchanged. The work-graph skill, the tracker reference and the dispatcher template say so.
