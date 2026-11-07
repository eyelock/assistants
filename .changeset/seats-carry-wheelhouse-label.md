---
"@eyelock-assistants/wheelhouse": minor
---

Every seat's harness carries `wheelhouse:<name>`: `create-wheelhouse` writes it into the desk's manifest and `add-seat` into each seat's, filled in with the Wheelhouse's own name, and the doctor warns about a harness without it or with another Wheelhouse's, and says how to fix it. With it, `ynr query --label wheelhouse:<name>` picks out one Wheelhouse's run records when several share the laptop spool. Needs the ynh release with harness labels.
