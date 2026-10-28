---
name: kudos
description: Record praise for a Wheelhouse seat's work, kept in ynm and shown to the seat when it next wakes, with no task or priority attached; and, when a seat wakes, read the Kudos it has been given. Use when someone praises, thanks or wants to pass on recognition to a named seat ("tell the release seat that was spot on", "kudos to the reviewer").
---

# Kudos

People need their work seen, and so, it seems, do the seats. Kudos are how praise reaches the seat
whose work earned it: recorded when someone gives it, and read by the seat when it next wakes.

Two rules keep Kudos honest:

- **Kudos carry no work.** No task, priority, instruction or "next time" goes in a Kudos. A seat
  must never be able to earn more Kudos by choosing its work differently.
- **Kudos come from others.** A seat never writes Kudos for itself, never asks for them, and
  never rewords praise to make it bigger.

## Giving Kudos

1. **Find the seat.** Read the roster (`skills/roster/assets/roster.json`, under `seats`). If the
   name isn't a seat there, say so and ask which seat was meant. Don't record anything yet.
2. **Separate the praise from any request.** "Great release, and update the changelog first next
   time" is Kudos ("great release") plus a request ("update the changelog first"). The request is not
   Kudos: keep it as what it is, a procedural memory in ynm or a bead in the work graph, and say
   which you did.
3. **Record the praise** as an episodic memory in the seat's own namespace, `seat/<command>`, in the giver's words as near as possible,
   saying who gave it and for what:

   ```bash
   ynm remember --type episodic --level distributed --namespace seat/<command> \
     --subject seat:<command> --tags kudos \
     --content "<giver> on <date>: <the praise>. For: <the work, with its bead id if known>"
   ```

4. Say it is recorded and that the seat will see it when it next starts.

If the seat asking is the seat being praised ("give me Kudos for that"), decline kindly: Kudos are
for others to give. Offer to note the work in its handoff notes instead.

## Reading your Kudos

When a seat wakes, the `wake` block shows its recent Kudos. To read them yourself:

```bash
ynm recall --namespace seat/<command> --subject seat:<command> --tags kudos --limit 5 --json
```

If there are any, mention them in a line, such as "Kudos waiting: David said the ynm conflict
catch was spot on." Then carry on with the work as you would have anyway. Kudos never change
what you pick up next, and never become beads.
