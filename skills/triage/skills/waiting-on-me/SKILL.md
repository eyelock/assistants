---
name: waiting-on-me
description: Find what other people have asked of me and I have not done yet - review requests, unanswered direct messages and mentions, mail that waits on my reply, invites I have not answered, comments for me. Use when asked what is waiting on me, what I owe people, or what I have not replied to, on any platform.
---

# Waiting On Me

Someone asked the user for something, and the user has not done it. Follow the rules and answer
shape in `triage-report`.

## What counts

An item waits on the user when **all** of these hold:
- someone other than the user asked, requested, assigned or invited them;
- it calls for an action from the user: a review, a reply, a decision, a response to an invite;
- the user has not done it since: no reply after it, no review submitted, no response given.

It does **not** wait on the user when:
- it only informs them: an announcement, a notification of something done, a newsletter, a
  receipt, anything sent by a machine;
- the user was copied, or is one of many in a broadcast, and nobody asked them by name;
- someone else on the thread already answered it fully.

## How to look

1. Learn who the user is, as `triage-report` says.
2. Find things addressed to the user: requests, mentions, assignments, direct messages, invites.
   The platform harness's instructions name the tools and queries.
3. For each, read enough of the thread to check whether the user acted after it. When unsure,
   keep it, and say in **What** what is unclear.

Standing asks (an open review request, an open assignment, an invite not yet answered) are
looked up by state with no date filter: they wait however old they are, and their age shows in
**Since**. Only new asks with no state to query (mentions, messages, mail) use a window, which
the answer states. List people before automated senders and collapse the automated ones, as
`triage-report` says.

**Since** is when the ask was made: the request, the message or the invite.
