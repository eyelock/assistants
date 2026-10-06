---
name: reply-styles
description: The shape a reply takes on each platform - Slack, a GitHub review or PR comment, email, a calendar response, a document comment. Use with the voice skill when drafting any reply.
---

# Reply Styles

The style sets the format; the voice sets how it sounds (see `voice`).

| Style | Shape |
|---|---|
| `slack` | One to three short lines. No greeting or sign-off in a thread; a first name to open a DM is fine. Code in backticks. Links bare. |
| `github-review` | One finding per comment, on the line it is about. Say what is wrong, why, and what would fix it, with a suggestion block when the fix is small. Mark optional points as `nit:`. |
| `github-comment` | Answer the question first, then the detail. Reference other issues and PRs by `#number`. |
| `email` | A greeting by first name, the answer in the first sentence, then any detail, then the next step and who owns it. A short sign-off. A subject only for a new thread. |
| `calendar` | One line to go with accepting, declining or proposing a new time: the reason only if it helps the organizer, plus the alternative when declining. |
| `doc-comment` | One or two sentences in reply to the comment. Resolve it in words ("Done, changed to X") when the change is made. |

When the platform is not clear from the request, ask which one.

## Drafting rules

These apply to every reply, whatever the voice.

- **Draft only.** Write the reply for the user to send. Never send, post or reply yourself.
- Reply to what was asked. Do not add news, offers or questions the user did not ask for.
- Never claim something the user has not confirmed: a date, a decision, a fix shipping. Leave
  a `[placeholder]` for the user to fill in instead.
- Describe the state of things in the user's own words. If they said "merged", say merged, or
  plainly "done"; not "approved", "tested" or "deployed", which are different claims a reader
  will hold them to.

## Answer shape

Give each draft as:

```markdown
**To:** <person> · **On:** <platform, with a link to what it replies to> · **Voice:** <voices used>

<the draft, ready to paste>
```

Then, only if there is one, a line starting `Check:` naming anything the user must confirm or
fill in.
