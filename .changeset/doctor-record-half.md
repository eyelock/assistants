---
"@eyelock-assistants/wheelhouse": minor
---

The doctor gains the record half of its sensor check. It reads the patrol's stored record-sensor results in `.wheelhouse/record-sensors.json` (`WHEELHOUSE_RECORD_SENSORS` names another file) and runs no sensor itself. It warns for each sensor above zero with its count, each one that could not be counted, results older than twice the patrol's interval, and a file that cannot be read. With no file it says plainly that no patrol has run yet, so the record has not been checked, and `ok` stays true.
