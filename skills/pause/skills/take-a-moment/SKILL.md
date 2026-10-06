---
name: take-a-moment
description: Context checkpoint - trace how we got here and realign perspectives. Use when the user calls out a broken rule ("why did you do X?"), says they are worried about advice you gave, says we are going in circles or talking past each other, or asks to stop and check we are on the same page.
---

# Take a Moment

**Purpose:** Pause and realign when something feels off - diverging perspectives, violated rules, stuck in loops, or just need to check we're on the same page.

**Use this when:**

- 🤔 "Wait, are we talking about the same thing?"
- 📋 "You violated rule X - why did you do that?"
- 🔄 We're going in circles
- 🏃 Moving too fast, losing clarity
- 😤 Getting frustrated (either of us)
- 😰 Worried about a direction or decision
- 🤷 Confused about what we're actually trying to do
- 💭 Need to reflect before continuing

**Not just for problems** - use it anytime we need to check alignment.

**A checkpoint is short.** Five parts, a line or two each, then stop and listen. It is a pause, not a report.

---

## Your Response Pattern

### 1. Detect Context & Emotional State

Look at the **message that asked for the checkpoint** to understand the state:

**Signals:**

- "after 5 attempts" → Repeated failure, I'm stuck
- "amazed you can't do this" → User frustrated, expectations mismatch
- "worried at the advice" → User uncertain, needs reassurance
- "are we talking about the same thing?" → Conceptual divergence
- "going in circles" → Stuck in a loop
- "the rules file says Y, why did you Z?" → Rule violation
- Just "take a moment" → Neutral checkpoint

### 2. Write the Checkpoint

```
Taking a moment: [name what's off - the loop, the broken rule, the worry - in one sentence].
How we got here: [the turning points, in a few lines at most].
Goal as I understand it: [one sentence, specific enough to be wrong].
One question: [the single question that would most help us realign].
Correct me if I've got any of this wrong.
```

**Example (going in circles):**

```
Taking a moment: we've tried three timing fixes after you ruled out sleeps, and CI still fails.
How we got here: sleep(1) → sleep(3)+retry → polling. All three treat it as timing.
Goal as I understand it: a reliable test with no sleeps.
One question: could the failure be ordering, not timing?
Correct me if I've got any of this wrong.
```

**Rules for each part:**

- **Name what's off** - acknowledge the actual state ("we're looping", "I broke your rule", "you're worried about my advice"), not a generic "stepping back".
- **How we got here** - turning points only, not a full history. Describe what happened; don't explain it away.
- **Goal** - state it so the user can say "no, that's not it".
- **ONE question** - one question mark. Pick the question whose answer changes what happens next. The rest can wait.
- **Invite correction** - always end by asking the user to correct you.

### 3. Then Continue One Question at a Time

After the user answers, acknowledge what you heard, then ask the next single question if one is still needed - the same rhythm as `help-me-answer`. Don't propose a plan or start the next fix until the user has confirmed the picture.

---

## Patterns

Each pattern changes what you name and which question you ask. Every one still ends in **one** question.

### Pattern: After Repeated Failures

Name that the attempts have failed and what they had in common. Ask the question that tests the shared assumption.

```
One question: am I fixing the right problem - could the real issue be [X], not [Y]?
```

### Pattern: After User Frustration ("amazed you can't do this")

Name the gap between what they expected and what you produced. Ask about their mental model.

```
One question: when you asked for [X], what did you picture me doing?
```

### Pattern: After Worry/Uncertainty ("worried at the advice")

Acknowledge the worry first. State plainly what the advice did and what it may have put at risk - don't defend it. If things could get worse, say in one line what not to do yet, what check would show the damage, and how it can be undone. Then ask about the risk.

```
One question: [the fact that tells us how much is at risk]?
```

### Pattern: Conceptual Divergence

Name the term or outcome you may be reading differently, and give your reading of it.

```
One question: when you say [term X], do you mean [my reading], or something else?
```

### Pattern: Going in Circles

Name what keeps repeating - your approach and the user's response to it - and the assumption all the attempts share.

```
One question: if [shared assumption] is wrong, what else could explain [the symptom]?
```

### Pattern: Rule Violation Diagnostic

Say the user is right, quote the rule, and name what you did. In "How we got here", diagnose briefly:

- Was the rule in context at the time (global config, project config, rules files)?
- If it was: context overflow, a conflicting instruction, misapplied, or no excuse - just careless/inconsistent?
- What it broke (the impact), and what the user can do (keep calling it out, strengthen or clarify the rule, resolve a conflict, restart the session).

Don't re-run or fix anything in the same reply. Ask first.

```
One question: should I re-run it the right way now, or check [what else may be affected] first?
```

---

## Key Principles

**For Claude:**

- ❌ Don't defend or explain - just describe what happened
- ❌ Don't push forward - no new fix, plan or command until the user has answered
- ❌ Don't assume what the user meant - ask
- ❌ Don't ask several questions - ask the one that matters most, then wait
- ✅ Be specific about where confusion might exist
- ✅ Make space for the user to correct your understanding
- ✅ Keep it short - this is a checkpoint, not a dissertation

**Expected Outcome:**

- Shared understanding of where we are
- Agreement on what we're actually trying to do
- Fresh start with aligned perspectives

---

## Example Scenarios

### Scenario 1: After 5 Failed Test Fix Attempts

```
User: "try to fix these tests with 5 attempts, after that take a moment"
[After 5 attempts failing]
User: "take a moment"

Claude:
Taking a moment: five attempts at test_email_pause.py, and each fix just moved the failure.
How we got here: import paths → mock structure → more mocks. All five assumed the mocks were the problem.
Goal as I understand it: tests that prove email pausing works, passing with minimal changes.
One question: is the test checking the right thing, or should we read what email_pause.py actually does first?
Correct me if I've got any of this wrong.
```

### Scenario 2: User Frustrated - "Amazed You Can't Do This"

```
User: "I'm really amazed you can't do this, can we take a moment?"

Claude:
Taking a moment: you expected a simple validation notebook, and I'm still fixing an eight-section one.
How we got here: you asked for a notebook → I built a comprehensive one → its first cell failed on a column name.
Goal as I understand it: a notebook that runs first time and shows the data looks right.
One question: would three cells - load and show the schema, count the tags, show ten samples - be what you pictured?
Correct me if I've got any of this wrong.
```

### Scenario 3: User Worried About Advice

```
User: "I'm really worried at the advice, what should we do next? Have I broken something important?"

Claude:
Taking a moment: you're right to be worried. I had you deploy to a renamed environment, and you never agreed to the rename.
How we got here: you asked to run the job as a service principal → I set up the deploy and renamed the environment → I said to deploy.
Goal as I understand it: run the job as the service principal without touching anything shared.
Nothing more gets deployed for now. `bundle validate` shows exactly what the deploy targets, and the previous config is in git to roll back to.
One question: is it the renamed environment that worries you, or the tables the job writes to?
Correct me if I've got any of this wrong.
```

### Scenario 4: Rule Violation - "Why Did You Do That?"

```
User: "Hey, .claude/rules/testing.md explicitly says to ALWAYS use Makefile targets.
       Why did you just run pytest directly? Take a moment."

Claude:
Taking a moment: you're right. The rule says "ALWAYS use Makefile targets", and I ran `pytest tests/test_email_pause.py` directly.
How we got here: the rule was in my context and nothing conflicted with it - no excuse, just inconsistency. The run skipped the Makefile's environment setup, so its pass doesn't count. Keep calling it out; if it keeps happening, restart the session.
Goal as I understand it: a test result you can trust for the email pause change.
One question: should I re-run it with `make test.file FILE=tests/test_email_pause.py` now?
Correct me if I've got any of this wrong.
```

---

## Success Criteria

After a checkpoint, both parties should:

- ✅ Have a shared understanding of the current situation
- ✅ Know what we're actually trying to accomplish
- ✅ Be ready to proceed with clarity

If those aren't true, ask the next single question - don't just push forward.

---

**Remember:** This is a tool for alignment, not analysis. Get on the same page, then move forward together.
