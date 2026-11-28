---
"@eyelock-assistants/wheelhouse": patch
---

The wake test "--end counts the kill grace in its budget" no longer measures wall-clock time, which a loaded macOS runner missed against both its 6 s and 8 s bounds. A perl stand-in records the limit and kill grace each sync's timer is given, and the test asserts the limit plus the grace stays inside the budget; a separate test checks a TERM-ignoring sync still ends with a timeout, with no time bound (assistants #351).
