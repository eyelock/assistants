---
"@eyelock-assistants/wheelhouse": patch
---

`wake.sh --end` runs the memory and work-graph syncs side by side under one 25-second budget (`WHEELHOUSE_END_SYNC_SECS` changes it, at most 28), so the worst case fits inside the 30-second session-end hook instead of two 30-second syncs overrunning it. It keeps their output: a sync the budget killed is reported as `timeout`, and one that failed as `failed`, each with an `errors` entry naming its exit code and the first line it printed.
