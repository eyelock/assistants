# Ask a triage question

Ask a read-only platform harness what is waiting on you, what you are waiting on, or to find
something. This page assumes the platform is already connected; if not, do
[Connect a platform](connect-a-platform.md) first.

Triage is one domain in this repository. The questions are the same on every platform, so you
learn them once.

## Install the harness

Install the harness for the platform from this repository, for example Slack:

```bash
ynh install github.com/eyelock/assistants --path ynh/slack
```

The ids are `github.com/eyelock/assistants/<name>`, where `<name>` is `github`, `slack`, `gmail`,
`google-calendar`, `google-drive` or `imessage`. See [Harnesses](../reference/harnesses.md).

> Not run: the platform harnesses, because they need credentials. The `planner` persona installs
> the same way and was run in [Run a persona](../tutorials/run-a-persona.md).

## Ask a question with a focus

A focus is a named prompt. Each question in [Triage questions](../reference/triage-questions.md)
is a focus with the same name:

```bash
ynh run github.com/eyelock/assistants/slack --focus waiting-on-me
```

Focuses run non-interactively and print the answer. Add `--interactive` to stay in the session
afterwards.

| To ask | Focus |
|---|---|
| What is waiting on me | `waiting-on-me` |
| What I am waiting on others for | `waiting-on-them` |
| What to act on today | `action-now` |
| What to act on soon | `action-soon` |
| What I promised | `my-commitments` |
| Catch me up on one thread or topic | `catch-up` |
| Find something someone said | `find` |
| The four main questions together | `all` |

`google-calendar` has no `my-commitments`, since a calendar holds invites, not promises. `imessage`
has no `all`. The table of who answers what is in
[Triage questions](../reference/triage-questions.md).

`catch-up` and `find` need a subject. Their prompts say to take it from the caller, and to ask if
none is given. Pass it as the prompt after the harness id:

```bash
ynh run github.com/eyelock/assistants/gmail --focus find "the invoice number from Acme"
```

> Not run: the exact placement of the subject on the command line. The usage line of `ynh run`
> is `ynh run [<harness-id|path>] [flags] [prompt]`.

## Ask a free-form question

Without `--focus`, give a prompt:

```bash
ynh run github.com/eyelock/assistants/github "which of my PRs are waiting on a review?"
```

## Choose how much the model sees (Messages only)

The `imessage` harness reads message text by default. To hide it, or to send counts only, pick a
profile:

```bash
ynh run github.com/eyelock/assistants/imessage --profile redacted --focus waiting-on-me
ynh run github.com/eyelock/assistants/imessage --profile counts --focus waiting-on-me
```

## What you get back

Every answer follows the `triage-report` skill: read only, one line per item, each linked to its
source. To combine answers from several platforms, ask each harness in turn and read the lists
together; the `triage-report` skill describes how to merge them.
