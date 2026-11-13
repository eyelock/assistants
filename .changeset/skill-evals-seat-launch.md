---
"@eyelock-assistants/wheelhouse": patch
---

A skill eval case can wake a seat through `ynh run` with `seat`, in a scratch `YNH_HOME` with the run's directory as `YNH_WORKSPACE_ROOTS`, so no `ynh trust accept` is needed. `VENDOR=` (or `--vendor`) picks the vendor, default claude. A new wake case wakes the worker template this way.
