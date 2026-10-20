# Triage questions

Generated from `skills/triage/skills/add-triage-question/assets/questions.json`. Edit that file, not this page. To add one, see [Add a triage question](../how-to/add-a-triage-question.md); for why the list is shared, see [Architecture](../explanation/architecture.md).

## Questions

| Id | Skills | Asks |
|---|---|---|
| `waiting-on-me` | `waiting-on-me` | find what is waiting on me {at}. |
| `waiting-on-them` | `waiting-on-them` | find what I am waiting on others for {at}. |
| `action-now` | `waiting-on-me`, `action-now-or-soon` | answer action-now: what I need to act on today {at}. |
| `action-soon` | `waiting-on-me`, `action-now-or-soon` | answer action-soon: what I need to act on soon {at}. |
| `my-commitments` | `my-commitments` | find the promises I made {at}: what I said I would do, to whom, the date and whether I appear to have done it. Take the period from the caller; default to the last 14 days. |
| `catch-up` | `catch-up` | catch me up on one conversation, thread or topic {at}: where it stands, what happened and what is open. Take the subject from the caller; if none is given, ask for one. |
| `find` | `find` | find what the caller asks for {at} (something someone said, a number, an address, a plan) and name where and when. Take the search from the caller; if none is given, ask for one. |

`{at}` is replaced by the platform phrase below.

## Platforms

| Id | Name | `{at}` |
|---|---|---|
| `github` | GitHub | on GitHub |
| `slack` | Slack | on Slack |
| `gmail` | Gmail | on Gmail |
| `google-calendar` | Google Calendar | on Google Calendar |
| `google-drive` | Google Drive | on Google Drive |
| `imessage` | Messages | in Messages |

## Who answers what

`on` means the platform answers now. `todo` means it should, and a change will add it. `not` means it cannot.

| Question | `github` | `slack` | `gmail` | `google-calendar` | `google-drive` | `imessage` |
|---|---|---|---|---|---|---|
| `waiting-on-me` | on | on | on | on | on | on |
| `waiting-on-them` | on | on | on | on | on | on |
| `action-now` | on | on | on | on | on | on |
| `action-soon` | on | on | on | on | on | on |
| `my-commitments` | on | on | on | not | on | on |
| `catch-up` | on | on | on | on | on | on |
| `find` | on | on | on | on | on | on |

## Why a platform cannot

- `my-commitments` on `google-calendar`: An event holds invites and meetings, not promises written in words, so a calendar has no sent items to read a promise from.
