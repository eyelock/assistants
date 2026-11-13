---
"@eyelock-assistants/wheelhouse": minor
---

The desk's wake lists every open ask between seats, from `ask.sh show --all`: each with its kind, asker, answering seat, age and the beads it blocks, oldest first, in both the JSON (`asks`) and the Markdown block. It says so plainly when the asks can't be read, in full or at all (a bd read that failed, `ask.sh` missing or broken), and never reports that as no open asks. The call is bounded by `WAKE_ASK_SECS` (default 30). Other seats' wakes carry no new section: their own asks already show under "Waiting for you".
