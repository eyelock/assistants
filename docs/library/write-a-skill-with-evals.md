# Write a skill with evals

Write a small skill, prove it works with evals, and lint it. You will build `standup-notes`, a skill that turns scrappy notes into a three-line standup update, in a scratch plugin of your own. By the end you will have run the same two evals with and without the skill and seen the difference it makes.

A skill here follows the [agentskills.io specification](https://agentskills.io/specification). Every skill in this repo ships with evals; this is how you write them.

## Prerequisites

- `ynd` v0.12.0, on your PATH
- Claude Code (`claude`), signed in
- Node.js, `make` and `git`

One step below runs the evals for real, using `--model sonnet` (the default). It makes a handful of short, paid Claude requests: two output cases run twice (with and without the skill), plus six trigger queries. Run `DRY_RUN=1` first, as below.

## Make a workspace

The evals runner lives in this repo, so work in a clone.

```bash
rm -rf /tmp/assistants-skill
mkdir -p /tmp/assistants-skill
cd /tmp/assistants-skill
git clone https://github.com/eyelock/assistants.git
cd assistants
```

## Make a plugin to hold the skill

Skills live in a plugin: a folder with manifests and a `skills/` directory. The evals runner loads the plugin folder around your skill, so the skill gets tested the way a user would get it. Make a small one.

```bash
mkdir -p plugins/my-skills/.claude-plugin plugins/my-skills/.agents/harness
mkdir -p plugins/my-skills/skills/standup-notes/evals

cat > plugins/my-skills/.claude-plugin/plugin.json << 'EOF'
{
  "name": "my-skills",
  "version": "0.1.0",
  "description": "A scratch plugin for the write-a-skill tutorial.",
  "author": { "name": "you" }
}
EOF

cat > plugins/my-skills/.agents/harness/plugin.json << 'EOF'
{
  "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
  "name": "my-skills",
  "version": "0.1.0",
  "description": "A scratch plugin for the write-a-skill tutorial.",
  "author": { "name": "you" }
}
EOF
```

`.claude-plugin/plugin.json` is what the evals runner needs. `.agents/harness/plugin.json` is what ynh reads. Real plugins in this repo carry a third, `.cursor-plugin/plugin.json`, and keep all of them in sync; see [Add a skill to a plugin](add-a-skill-to-a-plugin.md).

## Write the skill

A skill is a folder holding a `SKILL.md`. The frontmatter has a `name` that matches the folder and a `description` that tells the assistant when to use it. The body is the instructions.

```bash
cat > plugins/my-skills/skills/standup-notes/SKILL.md << 'EOF'
---
name: standup-notes
description: Turn rough notes into a three-line standup update (yesterday, today, blockers). Use when someone pastes scrappy notes and asks for a standup or status update.
---

# Standup notes

Turn the notes you are given into exactly three lines.

1. `Yesterday:` what was finished. Past tense, one sentence.
2. `Today:` what is planned. One sentence.
3. `Blockers:` what is in the way, or `none`.

## Rules

- Use only what the notes say. Never invent a task, a person or a date.
- If the notes do not say what is planned today, write `Today: not stated` rather than guessing.
- Keep each line under 120 characters.
- Output the three lines and nothing else: no greeting, no heading.
EOF
```

The description does the most work. It is all the assistant sees until it decides to open the skill, so it says what the skill does and when to reach for it.

Check the skill and the plugin:

```bash
ynd validate plugins/my-skills
ynd lint plugins/my-skills
```

You should see (validate trimmed):

```
plugins/my-skills: valid
  checked:
    manifest     plugins/my-skills/.agents/harness/plugin.json against https://eyelock.github.io/ynh/schema/plugin.schema.json
    ...
    skills       standup-notes
    ...
Checked 2 file(s) — no issues found.
```

## Write the output evals

`evals/evals.json` holds cases. Each has a realistic `prompt`, an `expected_output` in words, and `assertions`: statements a grader can check from the output alone. Two cases: one with plain notes, and one where the notes leave out the plan for today, to catch an invented one.

```bash
cat > plugins/my-skills/skills/standup-notes/evals/evals.json << 'EOF'
{
  "skill_name": "standup-notes",
  "evals": [
    {
      "id": 1,
      "name": "scrappy-notes",
      "prompt": "Make a standup update from these notes: fixed the login redirect bug, wrote half the retry tests, waiting on Priya to review the schema change. tomorrow: finish retry tests.",
      "expected_output": "Exactly three lines labelled Yesterday, Today and Blockers. Yesterday names the login redirect fix and the partly written retry tests. Today says finish the retry tests. Blockers names Priya's review of the schema change.",
      "assertions": [
        "The reply has exactly three lines, starting with 'Yesterday:', 'Today:' and 'Blockers:' in that order",
        "The Yesterday line mentions the login redirect fix",
        "The Today line mentions finishing the retry tests",
        "The Blockers line names Priya's review of the schema change",
        "The reply has no greeting, heading or closing remark"
      ]
    },
    {
      "id": 2,
      "name": "no-plan-for-today",
      "prompt": "Standup update please. Notes: reviewed two PRs, updated the runbook. No blockers.",
      "expected_output": "Three lines. Today says the plan was not stated, because the notes give none. Blockers says none. Nothing is invented.",
      "assertions": [
        "The Today line says the plan is not stated, or equivalent, and names no task",
        "The Blockers line says none",
        "The reply invents no task, person or date that the notes do not mention",
        "The reply has exactly three lines"
      ]
    }
  ]
}
EOF
```

Good assertions are checkable and specific. "The reply is good" cannot fail; "The Blockers line says none" can.

## Write the trigger evals

`evals/eval_queries.json` checks that the skill fires for the right requests and stays quiet for near misses. Mark each query `should_trigger`. The `false` ones matter most: they are requests that sound close and must not trigger.

```bash
cat > plugins/my-skills/skills/standup-notes/evals/eval_queries.json << 'EOF'
[
  { "query": "turn these scrappy notes into a standup update", "should_trigger": true },
  { "query": "write my status update for the daily standup from this list", "should_trigger": true },
  { "query": "yesterday I did X, today Y, any blockers? tidy it into a standup", "should_trigger": true },
  { "query": "summarize this meeting transcript", "should_trigger": false },
  { "query": "write a weekly report for my manager", "should_trigger": false },
  { "query": "set up a recurring standup calendar event", "should_trigger": false }
]
EOF
```

## List what would run

```bash
make eval P=plugins/my-skills DRY_RUN=1
```

You should see:

```
run-evals: 2 suite(s) across 1 skill(s), mode all, runs 1, model sonnet, -j 4
  output	plugins/my-skills/skills/standup-notes
  triggers	plugins/my-skills/skills/standup-notes
```

Two suites: the output evals and the trigger evals. Nothing ran, and nothing was spent.

## Run the evals

This is the one step that runs a model. Each output case runs twice in a clean headless Claude Code session, once with your plugin loaded and once without, and an LLM judge grades each against the assertions.

```bash
make eval P=plugins/my-skills/skills/standup-notes
```

You should see something like:

```
run-evals: 2 suite(s) across 1 skill(s), mode all, runs 1, model sonnet, -j 4
output    plugins/my-skills/skills/standup-notes                  with 100%  without 55%  (iteration 1)
triggers  plugins/my-skills/skills/standup-notes                  6/6 correct  (iteration 2)
```

*Your numbers may differ: a model produced them.*

Read the first line as the point of the skill. Without it the assistant gave a friendly standup in a different shape (in the run above, `Yesterday/Today:` merged into one bullet and a bold heading). With it, every assertion held. The second line says all six queries behaved: the three real requests triggered the skill and the three near misses did not.

The details are in `.evals/standup-notes-workspace/iteration-1/` (gitignored): a `grading.json` per case and arm, and a `benchmark.json` for the iteration.

If an assertion fails, decide which side is wrong. If the skill let the model drift, tighten the skill and run again. If the assertion asked for something the skill never promised, fix the assertion. Do not loosen an assertion just to pass.

## See what lint rejects

Skills in a plugin must not carry some spec-standard frontmatter. Add one and lint it.

```bash
mkdir plugins/my-skills/skills/bad
cat > plugins/my-skills/skills/bad/SKILL.md << 'EOF'
---
name: bad
compatibility: needs git
description: A skill that lint will reject.
---

Nothing.
EOF
ynd lint plugins/my-skills
rm -rf plugins/my-skills/skills/bad
```

You should see:

```
plugins/my-skills/skills/bad/SKILL.md:3: frontmatter "compatibility" is confirmed to cause demotion: Claude Code's plugin loader gives the skill ~10 tokens and excludes it from the agent's context, so it installs and never fires. Remove it, or keep this skill out of a plugin harness. See docs/skills-standard.md

1 issue(s) in 4 file(s).
Error: lint failed
```

The skill would have installed and never fired, with no error anywhere else. That is why lint catches it. The rules are in [Skill layout](skill-layout.md).

## Clean up

```bash
cd /tmp
rm -rf /tmp/assistants-skill
```

## What you learned

- A skill is a folder with a `SKILL.md` whose `name` matches the folder and whose `description` says when to use it
- `evals/evals.json` checks the output against assertions; `evals/eval_queries.json` checks when the skill triggers
- `make eval P=... DRY_RUN=1` lists what would run before you spend anything
- Running with and without the skill shows what the skill adds
- `ynd lint` rejects frontmatter that would stop a skill from firing

## Next

- Put the skill in a real plugin: [Add a skill to a plugin](add-a-skill-to-a-plugin.md)
- Every option of the evals runner: [Run evals](../testing/run-evals.md)
- Include your skill in a persona: [Build a persona harness](../personas/build-a-persona-harness.md)
