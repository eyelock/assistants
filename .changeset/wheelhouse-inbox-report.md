---
"@eyelock-assistants/wheelhouse": minor
---

The humans' inbox takes reports. `inbox.sh assign --kind report` makes a bead for a human to read, such as a weekly roadmap report or a milestone that moved: labelled `inbox:report`, priority 3 unless `--priority` says otherwise, with no `--url` or repository needed. `--priority <0-4>` sets any inbox bead's priority. `inbox.sh show` gives each bead its `kind` and lists reports after the rest, whatever their priority, and the desk's wake shows them under their own `Reports:` line, after the merges, reviews and decisions. The work-graph and wake skills, the plugin README and the Wheelhouse overview say so.
