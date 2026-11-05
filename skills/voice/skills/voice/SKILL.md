---
name: voice
description: How voices work - what a voice skill contains, how to write a new one, and how several voices compose into one reply. Use whenever drafting a reply in a named voice, or when asked to create or change a voice.
---

# Voice

A **voice** is how the user sounds. A **style** is the shape a platform expects (see
`reply-styles`). A reply has one style and one or more voices.

## A voice skill

Each voice is its own skill, named `voice-<name>`, with these sections and nothing else:

```markdown
---
name: voice-<name>
description: <one line: when this voice fits>
---

# Voice: <name>

One voice among several: combine it with others as the `voice` skill says, and draft by the
rules and format in `reply-styles`.

## Tone
<two or three lines: how it should feel to the reader>

## Length
<a target, e.g. "two sentences", "as short as it can be">

## Do
- <habits: open with the answer, name the next step, use first names...>

## Don't
- <habits to avoid: apologizing, hedging, exclamation marks...>

## Words
- Use: <words and phrases the user really says>
- Avoid: <words the user never says>

## Example
<one short reply in this voice>
```

To create a voice, ask the user for two or three replies they were happy with, and draw the
sections from those, not from adjectives. Show the draft skill before saving it.

## Composing voices

When a request names several voices, such as `direct + warm`:

1. Apply them in the order given. Where two voices disagree, the later one wins, for that
   point only.
2. **Length** comes from the shortest voice named, unless a later voice says otherwise.
3. **Don't** lists add up: a habit any named voice avoids is avoided.
4. **Words** add up the same way. If one voice uses a word that another avoids, avoid it.
5. The style's format always wins over every voice: a voice never turns a Slack reply into a
   letter.

When no voice is named, use the caller's default voice if they gave one, otherwise
`voice-direct`.

## Rules

The drafting rules in `reply-styles` apply to every reply, in any voice.
