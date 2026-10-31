---
name: comms
description: How a Wheelhouse seat talks to the humans - never naming a human in anything posted or written, asking decisions through the vendor's question tool with options (Claude Code's AskUserQuestion, or a numbered list where there is none), a synopsis beside every bead id, linked short ids and full paths, and the outcome first. Use whenever a seat (the desk or crew) reports to a human, asks a human to decide something, or writes a pull request, review, comment, bead, note or doc a human will read.
---

# Comms

How the seats talk to the humans. The humans read a lot from many seats: make every message easy
to act on, and never make them dig for what needs them.

## 1. Never name a human

In nothing posted or written: pull requests, reviews, comments, beads, notes, docs, commit
messages, handoffs. Write the next action impersonally:

- "Decision needed before merge: keep `--dry-run`, or rename it `--check`."
- "Next action: a maintainer merges [api #12](https://github.com/<owner>/api/pull/12)."
- "Waiting on review", not "waiting on <name>".

In chat, the human at the desk is "you". Who did what is in the work graph and the history;
prose needn't carry it. A seat's own byline, where the constitution asks for one, is a seat's
name, not a human's.

## 2. Ask decisions with the question tool

Gather what is waiting on a human, then ask it all at once through the vendor's structured
question tool (in Claude Code, `AskUserQuestion`):

- Up to 4 questions in one call; more than 4, ask the most urgent first and the rest next.
- Each question stands alone: one line of context (what it is about, with its linked short id or
  bead), then the question.
- 2 to 4 concrete options, each a short label and a line on what it means. Put the one you
  recommend first and end its label with "(Recommended)". Leave "other" to the tool: it always
  offers free text.
- Ask only what needs a human. What you may decide yourself, decide, and say what you chose.

Never list open questions in prose, and never repeat a "still waiting on you" list: ask through
the tool, once, and carry on with what doesn't wait on the answers.

**No question tool?** Where a vendor has none, ask in a numbered list, one decision per item,
each with its line of context and lettered options, the recommended one first:

```text
1. Release: api 1.4 is ready except for [api #12](https://github.com/<owner>/api/pull/12).
   a. (Recommended) Wait for #12, then release.
   b. Release now; #12 goes in 1.5.
```

Then stop, and wait for the answers.

## 3. Name things so they can be found

- **Every bead id has a synopsis:** "hq-12 (the changelog for api 1.4)", never a bare "hq-12".
- **Web resources by their short form, as links:** `[api #12](https://github.com/<owner>/api/pull/12)`,
  never a bare `#12` or a bare URL.
- **Local paths in full:** `/Users/<you>/<checkout>/AGENTS.md`, not a relative path, which
  hides which checkout or worktree is meant.

## 4. Outcome first, briefly

- Lead with the outcome: what happened, or what is ready. Then what changed. Then what needs the
  human, if anything, asked as in section 2.
- Keep status updates to a few lines. Don't narrate routine relays ("I passed that on"); say
  only what changed or what needs them.
- No walls of prose: a short list beats a long paragraph, and a table beats a long list.
