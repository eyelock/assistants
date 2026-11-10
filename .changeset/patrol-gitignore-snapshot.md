---
"@eyelock-assistants/wheelhouse": patch
---

`patrol.sh` makes `.wheelhouse/` ignore itself in git whenever the snapshot lives under it: the default, a `--snapshot` named in `.wheelhouse/` by a relative or absolute path, or one in a sub-folder made by hand. The patrol skill says so.
