---
"@eyelock-assistants/wheelhouse": patch
---

The wake shows a seat's whole Mandate. `wake.sh` read only the first line of the charter's `**Mandate:**` paragraph, so a mandate wrapped over several lines was cut short; it now reads to the next blank line and joins the lines.
