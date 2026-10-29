# Advanced: Triage

Triage answers a small, fixed set of questions about what needs you, such as what is waiting on
me, what I am waiting on and what to act on now, the same way on every platform you use: GitHub,
Gmail, Slack, Google Calendar and Drive, Apple Calendar and iMessage. Each platform is a thin,
read-only ynh harness in `ynh/<platform>` that adds one MCP server to the shared triage skills, so
a question is written once and every platform answers it alike.

It builds on the pieces before it: skills from the [Library](../library/README.md), and the MCP
servers, hooks and [Safety](../harnesses/safety.md) of [Harnesses in depth](../harnesses/README.md).
For a first platform harness built by hand, do
[Give a harness a tool](../harnesses/give-a-harness-a-tool.md).

## How-to guides

- [Connect a platform](connect-a-platform.md): credentials and one-off setup for each platform
  harness.
- [Ask a triage question](ask-a-triage-question.md)
- [Add a platform](add-a-platform.md): a read-only harness and platform skill for one tool.
- [Add a triage question](add-a-triage-question.md)

## Reference

- [Triage questions](triage-questions.md): the shared question list and which harness answers
  each.
- [Platform harnesses](harnesses.md): every platform harness, its MCP server, barrier and
  credentials.

## Explanation

- [How triage works](how-triage-works.md): the three layers, and why a question is written once.
