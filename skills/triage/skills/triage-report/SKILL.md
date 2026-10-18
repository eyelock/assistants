---
name: triage-report
description: The shared rules and table shape for every triage answer - read only, linked, one line per item - and how to merge answers from several platforms into one list. Use with waiting-on-me, waiting-on-them or action-now-or-soon, and when combining triage answers from GitHub, Slack, mail, calendar or documents.
---

# Triage Report

The triage skills answer four questions about one platform. This skill holds what they share:
the rules every answer follows, the shape it takes, and how answers from several platforms merge.

| Question | Skill |
|---|---|
| waiting-on-me | `waiting-on-me` |
| waiting-on-them | `waiting-on-them` |
| action-now, action-soon | `action-now-or-soon` |

## Rules

1. **Read only.** Never send, post, reply, react, approve, merge, archive, accept or decline.
   If a tool would change anything on the platform, do not call it.
2. **Only what you saw.** Every item comes from a tool result in this session and links to it.
   No link, no item.
3. **Me is the signed-in account.** Find out who that is first (the platform's "who am I" or
   profile tool) and use that identity throughout.
4. **Use the caller's context when it is given.** A caller may name key people, repositories,
   channels, labels or a time window. Outside a named scope, skip it.
5. **Standing items have no window; new asks do.** A standing item has a state you can query: an
   open review request, an open assignment, an invite not yet answered, an unresolved comment. It
   waits on the user however old it is, so query it by state with no date filter and show its age
   in **Since**. A time window only bounds new asks with no state to query: mentions, messages,
   notifications, mail. Without a window from the caller, look back 14 days for those. Where a
   platform has only recency to go on (Slack, Gmail, iMessage), keep the window as a practical
   bound. Whenever a window was used, say so in one line ("looked back 14 days for mentions") and
   offer to widen it.
6. **Done is done.** Skip items the platform shows as resolved: merged, closed, replied to,
   accepted, declined, resolved.
7. **Quote little.** Summarize each item in one line. Never copy whole messages, mails or
   documents into the answer.

## Answer shape

One Markdown table per question asked, newest first, then one line of counts. Use exactly these
columns, so answers from different platforms can be merged:

```markdown
### action-now

| Platform | What | Who | Since | Why now | Link |
|---|---|---|---|---|---|
| github | Review requested on "Add retry to sync" | @alice | 2026-10-03 | waited 2 days | https://github.com/org/repo/pull/12 |

Counts: waiting-on-me 7 (now 2, soon 5), waiting-on-them 3.
```

- **Platform:** the platform's name, lower case.
- **What:** one line, in your own words.
- **Who:** the other person: the asker for waiting-on-me, the one being waited on for
  waiting-on-them.
- **Since:** the date the wait started, `YYYY-MM-DD`.
- **Why now:** filled only in `action-now`, naming the rule that applied.
- **Link:** the platform's own URL for the item.

When a question has no items, write its heading and `Nothing.` When a platform could not be
read (an auth failure, a missing tool), say so in one line instead of guessing.

**People first, machines collapsed.** List items from people before items from automated senders
(bots, notification mail, dependency updaters). Collapse automated items into one row per kind of
sender, unless the caller asks for them listed: "33 automated Dependabot review requests across 6
repos, oldest 2026-10-07" with a search link as **Link**. Count the collapsed items in the counts
line.

**Order:** people's items first, then the user's own standing items (self-assigned, old
assignments), then automated rows last: they carry the least signal.

**Complete pages only.** A search that returns fewer rows than its total is a partial page. Take
counts from the total, not from the rows seen, and read further pages with the tool's own paging
parameters until all rows are read. If paging is not possible, say the list is partial and give
the total. Never state "N repos" or "oldest date" from a partial page without saying so.

Put the window line (rule 5) just before the counts line; it is the only line allowed there.

The counts line ends the answer. Do not follow it with what you checked or how: the caller
merges answers, and anything after the counts gets in the way.

## Merging platforms

When answers come from several platforms:

1. Keep each row as it came. Do not reword it.
2. Merge each question's rows into one table, ordered by **Since**, oldest first, so the
   longest waits lead.
3. When two platforms report the same thing (a GitHub review request and its notification
   mail), keep the row from the platform where it can be acted on, and drop the other.
4. End with one line of counts per platform, and one line naming any platform that could not
   be read.
