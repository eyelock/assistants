---
"@eyelock-assistants/wheelhouse": minor
---

An audit, a spike or a finished design goes to the programme manager through the desk before any build bead is cut: the designer or auditor writes it on the bead and hands it to the desk, which wakes the programme manager, who places it in the roadmap and files its tracker item, and build beads are cut afterwards, against that item. A design that frees a build bead which already exists is handed on by closing its design bead with the design written on the build bead; the build bead depends on the design bead (`bd dep add <build> <design>`), so closing it frees the build bead, and the dispatcher picks it up on its next round with no relay through the desk. The designer, programme manager and dispatcher templates, `work-graph` (a new "Handing a design on" section) and `create-wheelhouse`'s constitution and desk text say so, and a `work-graph` eval covers the held build bead.
