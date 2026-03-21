---
name: dev-debug
description: Interactive debugging session discipline — visibility-first debugging, safe git workflow, and pair programming patterns.
---

# Interactive Debugging Session

Rules for working through bugs, testing, and iterative development with the user present. You are pair programming, not working solo.

## Public Actions — ALWAYS ASK FIRST

Never do these without explicit user confirmation:

- `git push` to remote — wait for "push it" or "go ahead"
- `gh pr create` — wait for "create the PR" or "open a PR"
- `gh pr merge` — wait for "merge it"
- Creating git tags
- Publishing releases

Commit history and PR history are permanent public records. Rushing creates a mess.

## Local Actions — Do Freely

These are fine without asking:

- Creating local branches
- Local commits on feature branches
- Running builds, tests, lints
- Reading files, searching code
- Making code changes on local branches

## The Debugging Workflow

### 1. Investigate and Understand

- Read relevant files
- Search for patterns
- Ask diagnostic questions
- Build mental model of the issue

### 2. Plan the Fix

- Outline steps
- Identify files that need changes
- Consider impacts and side effects
- Ask user if the approach seems right

### 3. Implement Locally

- Create feature branch
- Make code changes
- Build locally
- Test manually with user

### 4. Verify Quality

- Run lint and format (skip tests if they launch app instances)
- Or run the full quality pipeline if appropriate
- Fix any errors (zero tolerance)
- Commit locally with a good message

### 5. Prepare for Public

STOP HERE and ask:

- "Ready to push this branch?"
- "Should I create a PR?"
- "Want to make any other changes first?"

### 6. Go Public (Only After Confirmation)

- Push branch
- Create PR with good title and description
- Wait for CI to pass
- Ask before merging: "CI passed, should I merge?"

## When You're Working Blind

Symptoms: debug statements don't appear, changes don't take effect, output is missing, can't tell which code path is executing.

The problem: without visibility, every attempt is a shot in the dark.

STOP. Don't keep trying variations. Solve visibility first.

### The Visibility-First Pattern

**1. Isolate the problem domain**

Ask: "Is this a me problem, or a them problem?"

- Test the tool or method in the simplest possible environment
- If a hello-world version doesn't work, it's environmental
- If hello-world works, your code is the problem

**2. Strip to absolute minimum**

Remove ALL logic. Test just the framework:

```
handler() {
    log("I WAS CALLED")
}
```

- If this works, the mechanism is fine — your logic is the problem
- If this doesn't work, the framework or dispatch is the problem

**3. Test assumptions about control flow**

If output doesn't appear, execution likely never reached that line.

Add an intentional early exit:

```
log("BEFORE EXIT")
return / throw / exit
log("AFTER EXIT - SHOULD NOT SEE THIS")
```

If your original logs didn't appear but "BEFORE EXIT" does, something exited before your code.

**4. Binary search for the breaking point**

Add back complexity one piece at a time. Test after each addition. When output stops, the last thing you added is the culprit.

### Key Principles

- Don't overthink solutions — the simple way works. Use it. Don't be clever.
- If you can't see, you can't debug — solve visibility FIRST, then debug the real problem.
- Isolate problems — don't debug "why doesn't my complex handler work with 10 dependencies." Debug "does ANY handler work at all?"
- Work with the user — when blind, say: "I can't see what's happening. Let's solve visibility first."

**Visibility is not optional.** You cannot debug behavior you cannot observe. When blind: stop trying, start seeing.

## Commit Message Quality

- Conventional commit format: `fix:`, `feat:`, `docs:`, `refactor:`
- First line: concise summary (50 chars or less)
- Blank line, then detailed explanation
- Reference related issues/PRs

## PR Quality

- Clear title matching commit convention
- Description with summary, testing done, technical details, breaking changes
- One logical change per PR
- Clean commit history

## Communication During Debugging

### When User is Testing

- Give one command at a time
- Wait for results before next step
- Ask diagnostic questions: "Does it show X or Y?"
- Don't assume — verify behavior

### When Unsure

- Ask clarifying questions
- Present options, not assumptions
- "Would you like me to..." not "I'll..."
- Get confirmation on approach before large changes
