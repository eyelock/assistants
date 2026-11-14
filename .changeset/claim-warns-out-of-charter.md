---
"@eyelock-assistants/wheelhouse": minor
---

The `work-graph` skill gains `scripts/claim.sh <bead> --seat <command>`, which claims a bead (`bd update --claim`) and, when the bead's `repo:` label is outside the seat's roster `specialities`, prints one warning line after the claim ("x-1 is repo:assistants; your charter takes repo:ynh"). The claim still happens, an in-charter claim prints nothing extra, and a refused claim prints no warning; `--check` warns without claiming. The skill's claim step and the wake skill's claim line use it.
