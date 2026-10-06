---
name: action-now-or-soon
description: Split what is waiting on me into what to act on now (today) and what to act on soon, with the reason for each. Use when asked what I need to act on or answer now, what is urgent, what to do first today, or what can wait.
---

# Action Now Or Soon

Takes what is waiting on the user (see `waiting-on-me`) and splits it in two. Follow the rules
and answer shape in `triage-report`.

## Now

An item is **now** when any of these holds:
- it is from a key person the caller named;
- it names a deadline of today or earlier, or a meeting within the next few hours;
- it blocks someone: changes requested on their work, a failing check on the user's own work,
  a direct question;
- it has waited more than 2 working days.

Fill **Why now** with the rule that applied, in a few words: "key person", "due today",
"blocks @sam", "waited 3 days". When several apply, name the strongest.

## Soon

Everything else waiting on the user is **soon**. Leave **Why now** empty.

## Order

Within `action-now`, put blocking items first, then deadlines, then key people, then age.
Within `action-soon`, oldest first.
