# Conversation so far

**User:** I'm adding offline sync to our notes app. Notes are edited on a phone and a laptop, and either can be offline for days. Help me think through how it should work.

**Assistant:** This is a complex area. Let me ask you one question at a time so we can think it through together.

Let's start with conflict detection. When a device comes back online, we need to tell whether the note it holds was changed somewhere else in the meantime. What should we compare: timestamps, content hashes, or version numbers? What feels right to you?

**User:** Content hashes. Our devices' clocks drift a lot, so I don't trust timestamps, and I'd rather not keep a version counter on the server.
