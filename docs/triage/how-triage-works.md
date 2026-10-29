# How triage works

Triage answers a small, fixed set of questions about what needs you (what is waiting on me, what
I am waiting on, what to act on now) the same way on every platform you use. It is the area where
every layer of the repo shows up at once: skills, a plugin, thin harnesses, MCP servers and
hooks. No other area depends on it. For the layers themselves, see
[Architecture](../start/architecture.md).

```
ynh/github                 thin harness: includes skills/triage, picks the github platform skill,
  |                        declares one MCP server, gives each question a focus
  v
skills/platforms/skills    platform skills: where to look on one platform
skills/triage/skills       generic triage skills: what to ask, and the shape of the answer
```

**Generic triage skills** (`skills/triage`) say what to ask and how to answer, without naming a
platform: `waiting-on-me`, `waiting-on-them`, `action-now-or-soon`, `my-commitments`, `catch-up`,
`find`, and `triage-report`, which holds the shared rules and answer shape. **Platform skills**
(`skills/platforms`) say where to look: each has a `SKILL.md`, `references/tools.md` for the
server's tools, and `references/triage.md` mapping each question to those tools.

The split pays off here for three reasons:

- A new question is written once, in the triage layer, and every platform answers it the same way.
  The common list lives in `skills/triage/skills/add-triage-question/assets/questions.json`.
- A new platform is one platform skill and one thin harness. It does not touch the triage skills.
- `pnpm test` fails when a harness and the common list disagree, or when a harness picks a skill
  that does not exist.

The same shape (a generic skill, a platform skill, a thin harness) could carry another domain.
Nothing in the layering is specific to triage.

For the harness-by-harness facts, see [Platform harnesses](harnesses.md) and
[Triage questions](triage-questions.md). For how the platform harnesses are kept read only, see
[Safety](../harnesses/safety.md).
