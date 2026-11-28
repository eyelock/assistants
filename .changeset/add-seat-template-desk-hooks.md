---
"@eyelock-assistants/wheelhouse": patch
---

The add-seat harness template includes the desk (`"git": "../.."`) with `"hooks": false`, and says why, so a new seat no longer prints "included harness ../.. declares hooks ... that are not active" on every launch. A test reads the template and the add-seat eval expects the field (assistants #347).
