---
name: add-triage-question
description: Decide whether a new question belongs on the common triage list, and if so add it and keep every platform harness in step. Use when someone wants a new triage, inbox or "what needs me" question across platforms, asks whether something is a platform feature or something for all the triage skills, or asks whether it should be a common question.
---

# Add A Triage Question

**Requirements:** Node.js 20 or later and a checkout of eyelock/assistants. The scripts in
`scripts/` read and write `ynh/*/.agents/harness/plugin.json` and read `skills/platforms`. They
use no network.

The common list is the set of questions every platform harness can answer the same way, so one
orchestrator can ask them all the same thing. It lives in `assets/questions.json`. A question
costs every platform a skill note and a focus, so most ideas should stay off it.

## First decide: does it belong on the list?

Add it only when **all** of these hold:
1. **It is a question, not an action.** It reads and reports. It never sends, posts, drafts,
   replies, merges, archives, accepts or declines.
2. **It makes sense on two or more platforms** and can be put without naming one. "What did I
   promise?" works on mail, chat and code review. "Which workflow runs failed?" does not.
3. **It is not a variation of a question already there.** "Only from Sam", "only this week",
   "only the urgent ones" and "only in this repository" are things a caller says to an existing
   question, not new questions.
4. **A different skill would answer it.** If the same skill and the same rules answer it, extend
   that skill instead.

## When NOT to add

Leave it off the list, and put it where it belongs instead:
- **A feature of one platform** ("my failing workflow runs", "docs shared with me"): the
  platform's own skill or harness, and a focus in that harness only.
- **An action** (reply, draft, merge, archive, accept): a different risk tier, in a different
  harness. Never a triage question.
- **A filter, scope or ordering** of an existing question: a parameter the caller passes.
- **A report format, a digest or a schedule:** that is how an answer is presented or run, and
  belongs to the orchestrator or the harness that runs it.
- **A one-off task** you would not ask twice.
- **A question only one platform can ever answer.** Keep it on that platform. If a second one
  later can, move it to the list then.

When unsure, do not add it. Moving a platform focus onto the list later is cheap. Taking a
question off the list means changing every platform.

## How to add it

1. Write the generic skill in `skills/triage/skills/<name>`, platform-free, with evals
   (`evals/evals.json`, `evals/eval_queries.json`). Follow `triage-report` for the rules and the
   table shape.
2. Add an entry to `assets/questions.json`: `id`, `skills`, `ask` (the sentence after "Use the
   skill to", with `{at}` where the platform goes: "on GitHub", "in Messages") and put **every**
   platform in exactly one of:
   - `on`: the platform answers it now;
   - `todo`: it should, and a pull request will add it;
   - `not_on`: it cannot, with `{"<platform>": "<the reason, a sentence>"}`.
3. For each platform in `on`, add to `skills/platforms/skills/<platform>/references/triage.md`
   where to look for it on that platform.
4. Run `node scripts/triage-questions.mjs sync`, then format the changed manifests. This writes
   the focus into each harness in `on`.
5. Run `node scripts/triage-questions.mjs check`. It reports every mismatch between the list and
   the harnesses, and `pnpm test` runs it.

To move a platform from `todo` to `on`, do steps 3 to 5 for that platform alone, in its own pull
request.

## The list file

```json
{
  "platforms": { "github": { "name": "GitHub", "at": "on GitHub" } },
  "questions": [
    {
      "id": "my-commitments",
      "skills": ["my-commitments"],
      "ask": "find the promises I made {at}: ...",
      "on": ["github"],
      "todo": ["slack"],
      "not_on": { "google-drive": "Documents hold no sent items to read promises from." }
    }
  ]
}
```

A new platform harness goes in `platforms`, and then in a bucket of every question. The check
fails for a harness that includes `skills/triage` and is missing from `platforms`.
