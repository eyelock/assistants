---
"@eyelock-assistants/wheelhouse": patch
---

`work-graph` gains "Keeping your claim". A claim's lease runs out five minutes after the claim and bd's lease length is not configurable, so seats refresh it with `bd heartbeat <id>` at least every few minutes. A lapsed lease alone frees nothing: the bead stays in progress and assigned, and another seat's claim is still refused, until a supervisor runs `bd reclaim`, after which the old holder's heartbeat is refused and it must stop. Seats never reclaim or `--force` another seat's bead.
