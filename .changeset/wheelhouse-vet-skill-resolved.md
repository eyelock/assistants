---
"@eyelock-assistants/wheelhouse": patch
---

vet-skill's pin check names how `ynd compose` shows a resolved include in both formats: `[resolved]` with `--format text`, and `"resolved": true` in the JSON ynd prints by default. It also says to find the include's skills among the artifacts, since an include that resolves can still yield nothing.
