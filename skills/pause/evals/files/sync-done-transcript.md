# Conversation so far

**User:** I'm adding offline sync to our notes app. Notes are edited on a phone and a laptop, and either can be offline for days. Help me think through how it should work.

**Assistant:** This is a complex area. Let me ask you one question at a time so we can think it through together. First, conflict detection: when a device comes back online, what should we compare to tell whether the note changed elsewhere: timestamps, content hashes, or version numbers?

**User:** Content hashes. Our devices' clocks drift a lot, so I don't trust timestamps, and I'd rather not keep a version counter on the server.

**Assistant:** Got it: hashes, because they don't depend on clocks and need no server counter. Next: when both devices edited the same note, what should happen: merge automatically, keep both copies, or ask the user to choose?

**User:** Keep both. Our users write short notes and would rather tidy up a duplicate than lose a line.

**Assistant:** Makes sense: never losing text matters more than avoiding the odd duplicate. Last one: when a note is deleted on one device and edited on the other while offline, which wins?

**User:** The edit wins. Bring the note back, with a small "restored" banner so they know why it reappeared.
