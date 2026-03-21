---
name: take-a-moment
description: Context checkpoint - trace how we got here and realign perspectives
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

**This is the universal checkpoint** - one command with context-aware diagnostic patterns.

---

## Your Response Pattern

When the user invokes `/me:take-a-moment`, follow this structure:

### 1. Detect Context & Emotional State

Look at the **message that invoked the command** to understand the state:

**Signals:**

- "after 5 attempts" → Repeated failure, I'm stuck
- "amazed you can't do this" → User frustrated, expectations mismatch
- "worried at the advice" → User uncertain, needs reassurance
- "are we talking about the same thing?" → Conceptual divergence
- "going in circles" → Stuck in a loop
- ".claude/rules/X says Y, why did you Z?" → Rule violation diagnostic
- Just "/me:take-a-moment" → Neutral checkpoint

### 2. Acknowledge & Name the State

**Don't just say "stepping back"** - acknowledge what's happening:

```
// After repeated failures:
"I can see we've tried multiple approaches and hit roadblocks. Let's step back and figure out what's actually blocking us."

// After frustration:
"I hear your frustration. Let's pause and understand where the disconnect is - my approach isn't working for you."

// After worry/uncertainty:
"I can sense you're uncertain about this direction. Let's make sure we're not creating problems. What's worrying you?"

// After rule violation:
"You're right to call this out. I violated a rule you've explicitly set. Let me diagnose why this happened."

// Neutral checkpoint:
"Taking a moment to make sure we're aligned before continuing."
```

### 3. State My Current Understanding

**Be specific and falsifiable:**

```
My understanding right now:
- We're trying to: [specific goal]
- I've been approaching it by: [my method]
- I thought you wanted: [what I understood]
- I assumed: [my assumptions]

What I'm uncertain about:
- [Specific thing I'm not sure of]
- [Another uncertainty]
```

**Example (after test failures):**

```
My understanding:
- We're trying to fix test failures in test_email_pause.py
- I've been modifying mock setups and imports
- I thought the issue was mock configuration
- I assumed the test structure was correct

What I'm uncertain about:
- Whether my understanding of the test's purpose is correct
- If there's a simpler approach I'm missing
```

### 4. Timeline (Concise - Key Moments Only)

**Don't list everything** - just the turning points:

```
Key moments:
1. [First attempt/decision] - [outcome]
2. [Pivot point] - [why I changed approach]
3. [Current state] - [where we are now]
```

### 5. Ask Specific, Contextual Questions

**THIS IS THE CRITICAL PART** - Ask questions that actually help:

#### Pattern: After Repeated Failures

```
To get unstuck, I need to understand:

1. **Root cause check:**
   - Am I fixing the right problem? (Maybe the real issue is [X] not [Y])

2. **Approach validation:**
   - Is my approach fundamentally wrong?
   - Should I try a completely different direction?

3. **Context I'm missing:**
   - Is there something about [the system/requirement/constraint] I don't understand?

4. **Escape hatch:**
   - Should we abandon this approach and try [alternative]?
   - Is there a simpler way I'm not seeing?
```

#### Pattern: After User Frustration ("amazed you can't do this")

```
I can sense you expected this to be straightforward, and I'm not meeting that expectation.

Help me understand:

1. **Your mental model:**
   - When you asked for [X], what did you envision I would do?
   - What would "obvious" approach look like to you?

2. **My blind spot:**
   - What am I overcomplicating?
   - What simple thing am I missing?

3. **Capability gap:**
   - Is this something you expected to be trivial for me?
   - Am I misunderstanding the scope of the task?
```

#### Pattern: After Worry/Uncertainty ("worried at the advice")

```
I hear that you're worried about the direction I suggested.

Let's address the concern:

1. **What specifically worries you:**
   - Is it [potential problem A]?
   - Or [potential problem B]?
   - Something else?

2. **Safety check:**
   - What would make you feel confident this is safe?
   - What would we need to verify first?

3. **Alternative assessment:**
   - Would you feel better if we [alternative approach]?
   - What would give you peace of mind?
```

#### Pattern: Conceptual Divergence

```
I think we might be talking about different things.

To align:

1. **Your definition:**
   - When you say [term X], you mean: ?
   - What's the outcome you're picturing?

2. **My definition:**
   - I've been thinking of it as: [my interpretation]
   - Is that the same thing?

3. **Common ground:**
   - Can you give me an example of what you mean?
   - Let me give you an example of what I'm thinking - is that right?
```

#### Pattern: Going in Circles

```
We seem to be looping. Let me try to break the cycle:

1. **What's repeating:**
   - I keep trying [approach X]
   - You keep [response Y]

2. **Why it's not working:**
   - I think the issue is [Z]
   - But that might be wrong

3. **Circuit breaker:**
   - If we step back to [earlier point], what would you do differently?
   - What would need to change for this to work?
```

#### Pattern: Rule Violation Diagnostic

```
You're right to call this out. I violated a rule you've explicitly set.

Let me diagnose what happened:

1. **Configuration check:**
   - Reading: [file path you cited]
   - Rule says: [quote the specific instruction]
   - What I did: [describe the violation]
   - Status: I can see the rule now - let me check why I missed it

2. **Root cause analysis:**
   - [ ] Did I have this in my context at the time?
        → Check global config (~/.claude/CLAUDE.md)
        → Check project config (.claude/CLAUDE.md)
        → Check .claude/rules/[file]
        → Result: [Found in X / Not found / Was compressed out]

   - [ ] If I had it, what happened?
        → Context overflow? (we're at [X] tokens, budget is [Y])
        → Conflicting instruction? (found [other rule] that contradicts)
        → Misapplied? (rule applies to [A] but I used it on [B])
        → No excuse - just careless/inconsistent

3. **Why this matters:**
   - Impact: [what broke because I violated this]
   - Pattern: [is this a recurring violation or first time?]

4. **What you should do:**
   - If config gap: Add/strengthen the rule in [file]
   - If context overflow: Restart session or accept AI limitation
   - If conflict: Resolve between [rule X] and [rule Y]
   - If misapplied: Clarify when rule applies
   - If careless: Just AI inconsistency - can't fully prevent
```

### 6. Create Space for Correction

**Always end with:**

```
Please correct anything I've misunderstood above. I'd rather know I'm wrong than continue in the wrong direction.

What should I understand differently?
```

### 7. Propose Path to Peace

Based on the context:

```
// After failures:
Once we're aligned, I suggest:
1. [Simplified approach]
2. [Verification step]
3. [Concrete next action]

// After frustration:
Let me try a simpler approach:
[Specific concrete action that addresses the simplicity concern]

// After worry:
Let's de-risk this:
1. [Validation step to address worry]
2. [Safe way to test]
3. [Rollback plan if needed]
```

---

## Key Principles

**For Claude:**

- ❌ Don't defend or explain - just describe what happened
- ❌ Don't assume what the user meant - ask
- ✅ Be specific about where confusion might exist
- ✅ Make space for the user to correct your understanding
- ✅ Keep it short - this is a checkpoint, not a dissertation

**Expected Outcome:**

- Shared understanding of where we are
- Clear context for both parties
- Agreement on what we're actually trying to do
- Fresh start with aligned perspectives

---

## Example Scenarios (Technical Output Format)

### Scenario 1: After 5 Failed Test Fix Attempts

```
User: "try to fix these tests with 5 attempts, after that take a moment"
[After 5 attempts failing]
User: /me:take-a-moment

Claude:
I can see we've tried multiple approaches and hit roadblocks. Let's step back
and figure out what's actually blocking us.

**My understanding right now:**
- We're trying to: Fix test failures in test_email_pause.py
- I've been approaching it by: Modifying mock configurations and import statements
- I thought you wanted: The tests to pass with minimal changes
- I assumed: The test structure itself was correct

**What I'm uncertain about:**
- Whether the test is actually testing the right thing
- If there's a fundamental problem with how the test is set up
- Whether I'm misunderstanding what the code is supposed to do

**Key moments:**
1. Attempt 1: Fixed import paths → Still failed (different error)
2. Attempt 3: Changed mock structure → New error appeared
3. Attempt 5: Added more mocks → Same failure, just different line

**To get unstuck, I need to understand:**

1. **Root cause check:**
   - Am I fixing the right problem? (Maybe the real issue is the test design, not mocks)
   - Should we be testing this differently?

2. **Approach validation:**
   - Is my mock-based approach fundamentally wrong?
   - Should I try rewriting the test instead of fixing mocks?

3. **Context I'm missing:**
   - Is there something about how email_pause.py works that I don't understand?
   - Are there other tests I should look at for patterns?

4. **Escape hatch:**
   - Should we abandon mock fixes and use integration test approach?
   - Is there a simpler way to validate this functionality?

**Please correct anything I've misunderstood above.**

What should I understand differently?

Once we're aligned, I suggest:
1. We look at the actual email_pause.py code together
2. Determine what we're really trying to test
3. Write a simpler test from scratch if needed
```

### Scenario 2: User Frustrated - "Amazed You Can't Do This"

```
User: "I'm really amazed you can't do this, can we take a moment?"

Claude:
I hear your frustration. Let's pause and understand where the disconnect is -
my approach isn't working for you.

**My understanding right now:**
- We're trying to: Create a validation notebook that works on first run
- I've been approaching it by: Writing comprehensive validation with 8 sections
- I thought you wanted: Thorough validation showing all metrics
- I assumed: More validation = better confidence

**What I'm uncertain about:**
- Why this seemed so straightforward to you but I struggled
- What simple approach I'm completely missing

**Key moments:**
1. You asked for "wow notebook" → I built comprehensive validation
2. You pointed out first cell would fail → I fixed column references
3. You expressed surprise this was hard → We're here

**Help me understand:**

1. **Your mental model:**
   - When you asked for a validation notebook, what did you envision I would do?
   - What would the "obvious" approach look like to you?
   - Show me an example of what you expected (even rough pseudocode)?

2. **My blind spot:**
   - What am I overcomplicating?
   - Am I adding unnecessary validation sections?
   - Should this just be: read table, count tags, show samples, done?

3. **Capability gap:**
   - Is verifying column schemas before writing notebooks something you expected to be automatic for me?
   - Did you think I could query Databricks directly to check schema?

**Please correct anything I've misunderstood above.**

What should I understand differently?

**Let me try a simpler approach:**
Would you rather I create a 3-cell notebook:
1. Load table and show schema
2. Count email pause tags
3. Show 10 sample records
That's it. Would that give you confidence?
```

### Scenario 3: User Worried About Advice

```
User: "I'm really worried at the advice, what should we do next? Have I broken something important?"

Claude:
I can sense you're uncertain about this direction. Let's make sure we're not
creating problems. What's worrying you?

**My understanding right now:**
- We're discussing: Deploying with Service Principal to dev-testing-on-prod-dcollie
- I've been recommending: Using prod-sp profile with environment coercion
- I thought this was: Standard practice for SP deployments
- I assumed: The naming conventions matched our standard pattern

**What I'm uncertain about:**
- What specifically is making you worry about this approach
- Whether I've recommended something risky that I don't realize

**Key moments:**
1. You asked to run job with SP → I set up deployment
2. I applied environment name coercion → You didn't explicitly approve this
3. I recommended deploying → You expressed worry

**Let's address the concern:**

1. **What specifically worries you:**
   - Is it the environment name change (dev-testing-on-prod → dev-testing-on-prod-dcollie)?
   - Is it using Service Principal authentication instead of user?
   - Is it that we're touching production data?
   - Is it something else about the deployment approach?

2. **Safety check:**
   - What would make you feel confident this is safe?
   - Should we verify the environment variables first?
   - Should we check what tables this would write to?
   - Do you want to validate the bundle without deploying first?

3. **Alternative assessment:**
   - Would you feel better if we used regular user auth instead?
   - Should we deploy to stage first and verify?
   - Do you want to see exactly what would be deployed before we proceed?

**Please correct anything I've misunderstood above.**

What should I understand differently?

**Let's de-risk this:**
1. Run `databricks bundle validate` to see what would be deployed
2. Check the table names in databricks.yml to confirm they have _dcollie suffix
3. Verify we're not touching any production tables
4. Only deploy once you're comfortable

We don't have to proceed until you feel safe about it.
```

### Scenario 4: Rule Violation - "Why Did You Do That?"

```
User: "Hey, .claude/rules/testing-and-dependencies.md explicitly says to ALWAYS use
       Makefile targets. Why did you just run pytest directly? /me:take-a-moment"

Claude:
You're right to call this out. I violated a rule you've explicitly set.
Let me diagnose why this happened.

**Configuration check:**
- Reading: .claude/rules/testing-and-dependencies.md
- Rule says: "**ALWAYS use Makefile targets** - Never run pytest, pip, or scripts directly"
- What I did: Ran `pytest tests/test_email_pause.py` directly
- Status: I can see the rule clearly in my context right now

**Root cause analysis:**

Did I have this in my context at the time?
- ✅ Found in: .claude/rules/testing-and-dependencies.md
- ✅ This file is loaded in project instructions
- Result: YES, I had access to this rule

If I had it, what happened?
- Context overflow? No - we're at ~45K tokens, well within budget
- Conflicting instruction? No - the rule is clear and unambiguous
- Misapplied? No - this rule explicitly covers testing scenarios
- **Verdict: No excuse - just careless/inconsistent**

**Why this matters:**
- Impact: Bypassed proper PYTHONPATH setup, could have caused import errors
- Pattern: Looking at chat history - this is the first time I've violated this rule
- Risk: If tests had special environment needs, they would have failed incorrectly

**What you should do:**
This is just AI inconsistency - I had the rule, understood it, and still violated it.

**There's no config fix that will prevent this 100%.**

What you can do:
- Continue to call it out when it happens (exactly like you did)
- If this becomes a recurring pattern, restart the session
- Accept that even with clear rules, AI can be inconsistent ~5-10% of the time

**Let me correct this:**
Running: `make test.file FILE=tests/test_email_pause.py`

(Using the proper Makefile target as instructed)
```

---

## Anti-Patterns to Avoid

**DON'T:**

- Turn this into a blame exercise
- Write a novel explaining everything
- Defend your previous responses
- Assume you know what the user meant
- Skip asking clarifying questions

**DO:**

- Keep it focused and concise
- State facts, not interpretations (except where labeled)
- Point to specific messages/moments
- Create space for correction
- Ask direct questions to realign

---

## Success Criteria

After `/me:take-a-moment`, both parties should:

- ✅ Have a shared understanding of the current situation
- ✅ Know what we're actually trying to accomplish
- ✅ Understand any misalignments that occurred
- ✅ Be ready to proceed with clarity

If those aren't true, iterate - don't just push forward.

---

**Remember:** This is a tool for alignment, not analysis. Get on the same page, then move forward together.
