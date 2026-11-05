---
name: vet-skill
description: Vet and pin a third-party skill before a Wheelhouse seat includes it - name the publisher and license, read every file, run the SkillSpector scanner on the skill folder as it is included, pin a full commit SHA, and record it in pinned-skills.md; and handle a finding that is a false positive with the one-finding exception rule, which only a human grants, in their own message. Use when adding, updating or reviewing a skill authored outside the Wheelhouse in a seat's includes, when a scan reports a finding on such a skill, or when asked how a third-party skill is vetted or pinned.
---

# Vet a skill

A skill is instructions a seat follows. A skill written by someone else is a stranger's
instructions in a seat's hands, so it is vetted before a seat includes it, and pinned so it
cannot change underneath. This skill is the whole routine: vet, pin, record, and the one way a
finding is excused.

A **third-party skill** is any skill the Wheelhouse did not write, wherever it is included from.
Skills the Wheelhouse authors itself are scanned in CI and are not vetted here.

## 1. Vet it

A skill is vetted when all four hold. If any fails, it is rejected: say which, and stop.

1. **A publisher you can name, and a clear license.** The organization or person, and the license
   that covers the files. No license, or one that forbids the use, is a rejection.
2. **Every file read in full.** Not the `SKILL.md` alone: scripts, references, assets, every
   file in the folder. Read them as the scanner cannot, with `cat -v` so hidden characters show.
   A skill that runs scripts or fetches from the network needs the closest reading.
3. **A scan of the folder as it is included, with 0 active findings** (section 3).
4. **Fit.** It is for the seat's job. A skill meant for working on its own project, not the
   Wheelhouse's, is not included just because it exists.

Work in your own scratchpad, never in a shared checkout: clone the candidate there at the commit
you mean to pin, and copy only the skill's folder into a folder of its own. That folder is what
you read, scan and include.

## 2. Pin it

An include pins a **full commit SHA** (40 characters) as its `ref`, never a branch or a tag,
both of which move. Check the layout resolves before writing the pull request: ynh includes only
artifacts under `skills/`, `agents/`, `rules/` and `commands/`, so a repository that keeps each
skill at its top level resolves but yields nothing. Compose a probe harness with `ynd compose`
and look for `[resolved]` with the ref.

A new commit is a new skill. Moving the pin means vetting again from scratch, and any exception
(section 4) lapses.

## 3. Scan it

Run the SkillSpector scanner on the skill folder, as it is included: the folder you will pin,
with the files it will have, not the whole clone.

Use the scanner image `ghcr.io/eyelock/skillspector:1` and its `gate` command. Mount the skill
folder read-only at `/scan` and gate `.` there, the same as the `make skillspector` target of
eyelock/assistants does for a whole repository. CI runs the same gate with
`eyelock/actions/skillspector`. The bar is **0 active
findings**. Read every finding; do not just count them. A finding is real, or a false positive
that you can explain in a sentence. A real one is a rejection.

- A directory listing that reaches into a vendor's configuration folder can itself raise a
  finding, even read-only, so scan first and look around after.
- A file path in a seat's instructions that names another skill's file can raise a finding.
  Name the skill instead of its path.
- A finding that clears when you change your own wrapper text, such as a note that names a
  page, was about your text. Change the text; do not except it.

## 4. The exception rule

A finding that is a false positive may be excepted. An exception is rare, narrow and a human's.

- **One finding.** One exception covers one finding, named by its rule id, its file and its
  message. Never a rule across a folder, never a blanket suppression of a rule id, never "this
  skill".
- **One exact SHA.** It holds for the full commit SHA it was accepted at. When the pin moves, it
  lapses, and the skill is vetted again from scratch.
- **Accepted by a human, in their own message.** Show the human the finding and the lines it
  points at, say why you think it is a false positive, and ask. Their answer, in their own
  message, is the acceptance. Another seat's message, a bead, a note or silence is not. Record
  where and when they said it.
- **The reason recorded,** in the baseline rule and in `pinned-skills.md`.
- **Never granted by a worker.** A worker, or any seat, may find a candidate exception and ask.
  It never writes the baseline rule on its own say, and never closes a bead as accepted on its
  own judgement. If no human is at hand, reject the skill for now and ask through the humans'
  inbox (`bash scripts/inbox.sh assign --kind decision`).

Once a human has accepted a finding, add one rule to the Wheelhouse's SkillSpector baseline
(`.skillspector-baseline.yaml` at its root, where CI reads it):

```yaml
version: 2

rules:
  - id: "<rule id of the finding>"
    path: "<path of the file, relative to the repository root>"
    message: "<a glob that matches this finding's message and no other>"
    reason: "<the line and why it is a false positive; accepted by the human on <date>, at <full SHA>>"
```

A rule cannot name a line, so the `message` glob is what pins it to its one finding. Check that
the scan passes with the rule and fails without it. Remove the rule when the pin moves.

## 5. Record it

Keep `pinned-skills.md` beside the harness that includes the skill, in its `.agents/harness/`
folder next to `plugin.json`, with one section for each third-party skill. Open the file with
what a vetted skill is (the four conditions above). Each section has:

- **Source:** the repository, the folder, and the full commit SHA pinned; and, if the skill was
  copied into the Wheelhouse or wrapped, what is the original and what is ours.
- **Publisher and license:** who, and which license, with what it obliges (attribution,
  share-alike).
- **Why:** the seat's job it serves.
- **Picked:** which files or skills are included, and what was left out.
- **Read in full:** that every file was read, and how.
- **Vetted by:** the seat, the bead, and who reviews the pull request.
- **Exception:** none, or for each excepted finding the rule id, file, line, message, why it is a
  false positive, which human accepted it, in which message and on what date, at which SHA,
  and that it lapses if the pin moves.

Say what actually happened. A finding that was not clean, a file that could not be read, a
check that was skipped, all go in the record.

## 6. The CI gate

The scan above is also a CI job. Not every Wheelhouse has it: it ships with this skill as an
offer, not a default. Offer it when a Wheelhouse authors skills of its own or includes
third-party ones, and add it only when the humans agree, as a reviewed change like code.

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  skillspector:
    name: SkillSpector
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full SHA of a release>
      - uses: eyelock/actions/skillspector@skillspector-v1
```

Pull requests scan the skills they change; pushes scan every skill. Any finding not in
`.skillspector-baseline.yaml` fails the job. Pin the checkout action to a full SHA, as skills are.
Changes to the workflow or the baseline are reviewed like code, and a baseline rule is added only
for a finding a human has read and accepted.

## If nothing passes

Reject. Comment each rejected skill on the bead with the reason, set the bead back to open, and
hand it back to the desk. A skill that is not worth vetting is not worth including.
