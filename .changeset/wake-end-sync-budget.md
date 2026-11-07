---
"@eyelock-assistants/wheelhouse": patch
---

`wake.sh --end` gives the session-end syncs 30 seconds, not 12 (`WHEELHOUSE_END_SYNC_SECS` changes it), and keeps their output. A sync the budget killed is reported as `timeout`, and one that failed as `failed`, each with an `errors` entry naming its exit code and the first line it printed, so a slow network is no longer an unexplained `failed`.
