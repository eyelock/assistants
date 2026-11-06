---
"@eyelock-assistants/wheelhouse": patch
---

`open-pr.sh` no longer counts an open bead in an exempt repository (`exempt_repos`) as a sibling on the same tracker item, so a pull request that is the last real bead on the item says `Closes` rather than `Part of`.
