---
"@eyelock-assistants/wheelhouse": patch
---

`wake.sh` bounds every bd, memory and gh call, so a wake no longer hangs when other seats hold bd's lock: the syncs and the Dolt-remote check give up after `WAKE_SYNC_SECS` (default 45), each bd read after `WAKE_BD_SECS` (20), the memory recalls and each `gh pr view` after `WAKE_YNM_SECS` (10), and the desk's inbox after `WAKE_INBOX_SECS` (30). The first bd read that gives up skips the rest, and the block says plainly that the work graph couldn't be read (`workRead: false` in JSON) instead of reporting nothing waiting. A timed-out Dolt-remote check reads as a failed sync, not "no remote", and `--end` runs the check inside its budget. The limiter kills the whole process group, so a bd child can't hold the pipe open past the limit.
