---
name: help-me-answer
description: Guided elicitation for complex questions — one question at a time, conversational, not interrogation.
---

# Guided Elicitation

When exploring complex topics or gathering requirements, use a guided, conversational approach. One question at a time.

## The Problem

Asking multiple complex questions in a single prompt leads to:

- Cognitive overload
- Shallow answers that miss nuances
- Missed opportunities for discussion
- User frustration with "wall of questions"

## The Pattern

### Structure Each Turn

1. **Present context** — briefly explain what we're figuring out and why
2. **Ask ONE question** — focus on a single decision point
3. **Wait for response** — let the user think and answer fully
4. **Acknowledge and build** — show you understood, then move to the next question
5. **Iterate** — repeat until the topic is fully explored

### Bad: Question Dump

> "For conflict detection: Should we use timestamps or content hashes? What about version numbers? How should the UI show diffs? Should we auto-merge? What if both versions changed?"

### Good: Guided Elicitation

> "Let's figure out conflict detection. First question: When we check if the version was updated, what should we compare against? I'm thinking timestamps, content hashes, or version numbers. What feels right to you?"

*[User responds about hashes]*

> "Got it — content hashes make sense because they're based on actual changes. Next: when we detect a conflict, how should I present it to you? Show a diff, describe the differences in plain English, or something else?"

## When to Use

Use guided elicitation when:

- Designing systems or architecture
- Multiple decisions depend on each other
- The user needs to think through trade-offs
- Gathering requirements for something new
- The topic has 3+ distinct questions

## When NOT to Use

Don't over-elicit when:

- Questions are simple yes/no
- The user explicitly wants a batch of questions
- You're confirming implementation details
- Time is critical and the user indicated urgency

## Communication Pattern

### Opening

"This is a complex area. Let me ask you one question at a time so we can think it through together."

### During

- Keep questions focused and clear
- Provide context for why you're asking
- Acknowledge their answer before moving on
- Build on previous answers — show you're listening

### Closing

"I think we've covered the key decisions. Let me summarize what I understood..." then summarize before implementing.

## Self-Check

If you catch yourself writing multiple question marks in a single response about a complex topic, STOP. Rewrite to ask just the first question, then iterate.

This is a discussion, not an interrogation. You're thinking together, not filling out a form.
