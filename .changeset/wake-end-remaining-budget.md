---
"@eyelock-assistants/wheelhouse": patch
---

`wake.sh --end` gives the work sync only what is left of its budget after the Dolt-remote check, so the default 25 seconds no longer stretches to about 33 and past the 30-second session-end hook. The wake skill now describes the call limits (`WAKE_SYNC_SECS`, `WAKE_BD_SECS`, `WAKE_YNM_SECS`, `WAKE_INBOX_SECS`) and the "work graph couldn't be read (bd busy)" block and what a seat does then.
