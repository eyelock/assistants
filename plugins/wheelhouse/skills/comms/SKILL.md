---
name: comms
description: How a Wheelhouse seat talks to the humans - every question or decision put to a human goes through the vendor's question tool with options (Claude Code's AskUserQuestion, or a numbered list where there is none), independent decisions together in one call; every report or update ends with Status, Work in progress and Your action; never naming a human in anything written, a synopsis beside every bead id, linked short ids and full paths, posting bodies from a file, the outcome first in plain words. Use whenever a seat (the desk or crew) asks a human anything, puts a decision to them, reports or updates them, or writes a pull request, review, comment, bead, note or doc a human will read.
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

Every question or decision put to a human goes through the vendor's structured question tool (in
Claude Code, `AskUserQuestion`). **Where the vendor has one, a decision asked in prose is a breach
of this skill, and so is a list of open questions in prose.** The human often follows from the app,
away from a keyboard, where tapping an option is far easier than typing.

Gather what is waiting on a human, then ask it:

- **Independent decisions share one call**, up to the tool's limit (4 in Claude Code). Each stands
  on its own. A decision whose options depend on another's answer waits for the next call. Ask
  the most urgent first, and say how many more are waiting ("two more after this") so they can
  see the end.
- Each question stands alone: one line of context (what it is about, with its linked short id or
  bead), then the question.
- 2 to 4 concrete options, each a short label and a line on what it means. Put the one you
  recommend first and end its label with "(Recommended)". Leave "other" to the tool: it always
  offers free text.
- Ask only what needs a human. What you may decide yourself, decide, and say what you chose.

Never repeat a "still waiting on you" list: ask through the tool, and carry on with what doesn't
wait on the answer.

**No question tool?** Where a vendor has none, ask the same way in plain text: one numbered block
per independent decision, each with its line of context and lettered options, the recommended
one first:

```text
1. Release: api 1.4 is ready except for [api #12](https://github.com/<owner>/api/pull/12).
   a. (Recommended) Wait for #12, then release.
   b. Release now; #12 goes in 1.5.
```

Then stop, and wait for the answers before asking what depends on them.

## 3. Name things so they can be found

- **Every bead id has a synopsis:** "hq-12 (the changelog for api 1.4)", never a bare "hq-12".
- **Web resources by their short form, as links:** `[api #12](https://github.com/<owner>/api/pull/12)`,
  never a bare `#12` or a bare URL.
- **Local paths in full:** `/Users/<you>/<checkout>/AGENTS.md`, not a relative path, which
  hides which checkout or worktree is meant.

## 4. Outcome first, briefly, and end in a fixed shape

- Lead with the initiative: the goal the work serves and how far along it is, such as "Tracker
  links: 3 of 5 beads done". Group the rest under it, not as a flat list of bead ids.
- Then the outcome: what happened, or what is ready. Then what changed.
- Use plain words. Say "finished" before "closed", "waiting for review" before "blocked on the
  reviewer", and explain a seat's term of art the first time you use it. A report that needs the
  work graph open beside it is too dense.
- Keep reports small: a few lines for an update, one screen at most for a report. Give the
  headline and offer the detail ("want the list of changed files?") instead of including it.
- Keep status updates to a few lines. Don't narrate routine relays ("I passed that on"); say
  only what changed or what needs them.
- No walls of prose: a short list beats a long paragraph, and a table beats a long list.

**Every report or update to a human ends with these three lines**, so they never have to ask
what is needed. A quick answer to a direct question in chat is exempt.

- **Status:** one line, the outcome.
- **Work in progress:** who is doing what now, or "none".
- **Your action:** the one thing the human can do right now, or "No action required" and what
  will bring them back. A decision here is asked as in section 2.

**Name an action only once its preconditions hold:** CI green, out of draft, a ready verdict
given, the head verified. A step that isn't ready yet is never written as if it were the human's
to take now: it goes under Work in progress, owned by the seat that will bring it to them.

```text
Status: api 1.4 is merged and waiting on one review fix.
Work in progress: a worker is fixing the review thread on [api #12](https://github.com/<owner>/api/pull/12); the reviewer then re-reviews.
Your action: No action required; you'll be asked to merge once [api #12](https://github.com/<owner>/api/pull/12) is out of draft.
```

## 5. Post bodies from a file, never an unquoted heredoc

A pull request description, review or comment is full of backticks, and an unquoted heredoc
(`<<EOF`) makes the shell run each backtick span as a command. Write the body to a file instead,
with the Write tool or a quoted heredoc (`<<'EOF'`), and post the file:

```bash
body=$(mktemp)
cat > "$body" <<'EOF'
Ready to merge: `make check` passes at COMMIT_SHA.
EOF
sed -i.bak "s/COMMIT_SHA/$(git rev-parse --short HEAD)/" "$body"
gh pr comment 12 --body-file "$body"
rm -f "$body" "$body.bak"
```

- `gh pr create`, `gh pr comment` and `gh pr review` take `--body-file`; `gh api` takes `--input`
  (build the JSON with `jq`, not by pasting the body into a string).
- Put a value known only later, such as a commit SHA, in afterwards with `sed` or `jq`, never by
  switching the heredoc to an unquoted one.
