---
"@eyelock-assistants/wheelhouse": minor
---

The dispatcher template names, in every dispatch note, the bead's tracker item (URL or key), its release, and whether its pull request closes the item or is part of it. It reads them from `open-pr.sh --dry-run` rather than working them out, so a note and the pull request the worker opens agree. With no tracker, the note has no tracker line, and a build bead the script refuses is left unassigned.
