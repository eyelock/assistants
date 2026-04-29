# vendor-harness

Lifecycle management for LLM vendor harness artifacts — across Claude Code, Cursor, and Codex.

## Core Concept

Every LLM coding assistant (Claude Code, Cursor, Codex) runs a **model** wrapped in a **harness** — everything that shapes what the model sees, what it can do, and how it behaves. That harness is assembled from discrete artifacts:

```
┌─────────────────────────────────────────────────────────┐
│                    LLM Vendor Platform                  │
│                                                         │
│  ┌─────────────┐  ┌────────────┐  ┌──────────────────┐  │
│  │   Model     │  │  Harness   │  │  Your Project    │  │
│  │  (GPT-4o,   │◄─┤            │◄─┤                  │  │
│  │  Claude,    │  │ Skills     │  │  CLAUDE.md       │  │
│  │  Sonnet...) │  │ Agents     │  │  AGENTS.md       │  │
│  └─────────────┘  │ MCP        │  │  .cursorrules    │  │
│                   │ Hooks      │  │  .claude/rules/  │  │
│                   │ Startup    │  └──────────────────┘  │
│                   │ Context    │                        │
│                   └────────────┘                        │
└─────────────────────────────────────────────────────────┘
```

This plugin provides the **lifecycle tooling** for those artifacts:

- **Validate** — is this artifact correctly formed for its target vendor?
- **Diagnose** — why isn't this loading, firing, or behaving correctly?
- **Feedback** — report a problem or propose a fix, routed to the right channel
- **Keep current** — track vendor documentation changes and update references as vendors evolve

## Artifact Types

Each artifact type influences the harness differently and has distinct spec, format, and vendor support:

```
┌──────────────────┬──────────────────────────────────────────────────-┐
│ Artifact         │ What it influences                                │
├──────────────────┼─────────────────────────────────────────────────-─┤
│ Skills           │ What the model knows how to do on demand          │
│ SubAgents        │ How the model delegates to specialist instances   │
│ MCP Servers      │ What tools the model can reach outside itself     │
│ Hooks            │ What intercepts the model at lifecycle boundaries │
│ Startup Context  │ What the model knows before any prompt            │
└──────────────────┴─────────────────────────────────────────────────-─┘
```

Vendor support varies significantly — and changes on vendor timelines:

```
                     Claude Code    Cursor     Codex
                     ───────────    ──────     ─────
Skills               ✓ full         ✓ full     ✓ full
SubAgents            ✓ full         ~ partial  ✗ none
MCP                  ✓ full         ✓ full     ✓ stdio only
Hooks                ✓ 25 events    ✓ 25 events  ~ 5 events (exp.)
Startup Context      ✓ CLAUDE.md    ✓ .mdc     ✓ AGENTS.md
```

## Agents

```
                    ┌─────────────────────┐
         user ────► │  harness-advisor    │ ◄── entry point
                    │  (elicit & route)   │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼───────────────────┐
              │                │                   │
              ▼                ▼                   ▼
  ┌───────────────────┐  ┌──────────────┐  ┌─────────────┐
  │ provenance-       │  │  feedback-   │  │ vendor-sync │
  │ detective         │  │  composer    │  │             │
  │                   │  │              │  │ fetch docs  │
  │ where did this    │  │ diagnose gap │  │ compare     │
  │ artifact come     │  │ select chan  │  │ update refs │
  │ from?             │  │ submit       │  │ flag gaps   │
  └───────────────────┘  └──────────────┘  └─────────────┘
```

| Agent | Owns |
|-------|------|
| `harness-advisor` | Conversational entry point — elicits what went wrong, identifies artifact type and vendor, routes to the right specialist |
| `provenance-detective` | Traces any artifact back to its origin git repo using multiple strategies |
| `feedback-composer` | Owns the feedback flow — diagnose gap, select channel, compose report, submit |
| `vendor-sync` | Keeps vendor references current — fetch, compare, update, flag gaps |

## Skills

```
  Artifact-specific                  Cross-cutting
  ─────────────────                  ─────────────
  skill-artifact                     locate-artifact-source
  subagent-artifact                  compose-feedback
  mcp-artifact                       submit-feedback
  hooks-artifact                     fetch-vendor-docs
  startup-context                    flag-vendor-gaps
                                     vendor-adapters  ◄── master ref
```

Artifact skills each carry per-vendor reference docs. Cross-cutting skills are called by agents across all artifact types.

## Workflows

### Workflow 1 — Something went wrong

```
  User: "my hook isn't firing in Cursor"
         │
         ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ harness-advisor                                             │
  │                                                             │
  │  Q: Which artifact type? ──► hooks                          │
  │  Q: Which vendor?        ──► Cursor                         │
  │  Q: What went wrong?     ──► didn't fire on file edit       │
  └───────────────────────┬─────────────────────────────────────┘
                          │ routes to provenance-detective
                          ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ provenance-detective                                        │
  │                                                             │
  │  try ynh ls ──► not found                                   │
  │  try ~/.cursor/plugins ──► not found                        │
  │  try git log --follow ──► found: github.com/org/repo        │
  │                                                             │
  │  check committer: gh api repos/org/repo/collaborators/me    │
  │  ──► is committer                                           │
  │                                                             │
  │  check local checkout: scan workspace paths                 │
  │  ──► found at ~/Workspace/org/repo                          │
  │                                                             │
  │  result: { source, is_committer: true, local: true }        │
  └───────────────────────┬─────────────────────────────────────┘
                          │ routes to feedback-composer
                          ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ feedback-composer                                           │
  │                                                             │
  │  load hooks-artifact + vendor-cursor reference              │
  │  diagnose: Cursor plugin uses flat legacy event names,      │
  │            not PascalCase — likely format mismatch          │
  │                                                             │
  │  compose-feedback: gather artifact, expected, actual,       │
  │                    reproduction, impact                     │
  │                                                             │
  │  submit-feedback: committer + local checkout                │
  │  ──► offer PR                                               │
  │  Q: "You have commit rights and the repo is checked out.    │
  │      Open a PR with the fix, or just file an issue?"        │
  │                                                             │
  │  ──► PR: create branch, apply fix, gh pr create             │
  └─────────────────────────────────────────────────────────────┘
```

### Workflow 2 — Validate an artifact

```
  User: "/vendor-harness:skill-artifact"  (or harness-advisor routes here)
         │
         ▼
  ┌────────────────────────────────────────────────┐
  │ skill-artifact                                 │
  │                                                │
  │  check frontmatter:                            │
  │    ✓ name present                              │
  │    ✓ description present                       │
  │    ✗ metadata field present ──► demotion bug   │
  │      in Claude Code, skill will not load       │
  │                                                │
  │  check directory layout:                       │
  │    ✓ SKILL.md present                          │
  │    ✓ scripts/ are chmod +x                     │
  │                                                │
  │  check description length:                     │
  │    ✓ 94 chars (under 130 limit)                │
  │                                                │
  │  report: 1 issue found (remove metadata field) │
  └────────────────────────────────────────────────┘
```

### Workflow 3 — Keep vendor references current

```
  User: invokes vendor-sync agent
         │
         ▼
  ┌────────────────────────────────────────────────────────────┐
  │ vendor-sync                                                │
  │                                                            │
  │  fetch-vendor-docs                                         │
  │    ├── GET code.claude.com/docs/en/hooks-guide             │
  │    ├── GET docs.cursor.com/advanced/mcp                    │
  │    └── GET developers.openai.com/codex/plugins             │
  │                                                            │
  │  compare against stored references/                        │
  │    ├── anthropic.md ──► no changes                         │
  │    ├── cursor.md    ──► OAuth section added to MCP         │
  │    └── codex.md     ──► hooks now GA (was experimental)    │
  │                                                            │
  │  present diff to user                                      │
  │    "2 changes found. Confirm to update?"                   │
  │                                                            │
  │  on confirm:                                               │
  │    ├── update cursor.md                                    │
  │    ├── update codex.md                                     │
  │    └── flag-vendor-gaps                                    │
  │          ──► resolve: "Codex hooks experimental"           │
  │                                                            │
  │  report: 2 references updated, 1 gap resolved              │
  └────────────────────────────────────────────────────────────┘
```

### Workflow 4 — Feedback without commit rights

```
  provenance-detective result:
    source: github.com/eyelock/assistants
    is_committer: false
    local: false
         │
         ▼
  ┌────────────────────────────────────────────────┐
  │ feedback-composer                              │
  │                                                │
  │  submit-feedback channel selection:            │
  │    not committer + GitHub repo found           │
  │    ──► file GitHub issue                       │
  │                                                │
  │  compose issue:                                │
  │    title: [hooks-artifact] ...                 │
  │    body: artifact, expected, actual,           │
  │           reproduction, impact                 │
  │                                                │
  │  show to user, confirm                         │
  │                                                │
  │  gh issue create \                             │
  │    --repo eyelock/assistants \                 │
  │    --title "..." \                             │
  │    --body "..."                                │
  └────────────────────────────────────────────────┘
```

## Provenance Detection Strategies

```
  given an artifact file
        │
        ├─1─► ynh ls --format json ──────────────────► installed_from.source
        │       (YNH harness install)
        │
        ├─2─► ~/.claude/plugins/ or .claude/plugins/ ─► plugin manifest
        │       (Claude Code native install)
        │
        ├─3─► ~/.cursor/plugins/ or .cursor/plugins/ ─► plugin manifest
        │       (Cursor native install)
        │
        ├─4─► ~/.codex/plugins/cache/ ───────────────► plugin manifest
        │       (Codex plugin install)
        │
        ├─5─► git log --follow <file> + git remote -v ► origin repo
        │       (embedded in current repo — check if worktree!)
        │
        ├─6─► walk up dirs for .claude-plugin/ etc. ──► manifest source
        │       (locally cloned plugin)
        │
        └─7─► ask user
                (all strategies failed)
```

## File Structure

```
vendor-harness/
├── agents/
│   ├── harness-advisor.md       entry point, routes to specialists
│   ├── provenance-detective.md  where did this artifact come from?
│   ├── feedback-composer.md     diagnose, compose, submit feedback
│   └── vendor-sync.md           keep vendor references current
│
└── skills/
    ├── skill-artifact/          Skills — spec, loading, vendor quirks
    │   └── references/
    │       ├── agentskills-spec.md
    │       ├── vendor-claude.md
    │       ├── vendor-cursor.md
    │       └── vendor-codex.md
    ├── subagent-artifact/       Agents — frontmatter, delegation
    │   └── references/  (vendor-*.md × 3)
    ├── mcp-artifact/            MCP — spec, transport, vendor support
    │   └── references/
    │       ├── mcp-spec.md
    │       ├── mcp-toolkit.md
    │       └── vendor-*.md × 3
    ├── hooks-artifact/          Hooks — events, types, format diffs
    │   └── references/  (vendor-*.md × 3)
    ├── startup-context/         CLAUDE.md, AGENTS.md, rules
    │   └── references/  (vendor-*.md × 3)
    ├── vendor-adapters/         Master cross-vendor reference
    │   └── references/
    │       ├── anthropic.md
    │       ├── cursor.md
    │       └── codex.md
    ├── fetch-vendor-docs/       Fetch current docs from vendor URLs
    ├── flag-vendor-gaps/        Maintain the known-gaps table
    ├── locate-artifact-source/  Multi-path provenance detective
    ├── compose-feedback/        Structured report template
    └── submit-feedback/         Channel selection + submission
```

## Keeping References Current

Vendor behavior changes frequently — sometimes days apart between vendors. The `vendor-sync` agent and `fetch-vendor-docs` / `flag-vendor-gaps` skills exist to make updates systematic rather than ad-hoc.

The master reference is `vendor-adapters` — it holds the complete cross-vendor format mapping tables and the known-gaps tracker. Per-artifact reference files (`hooks-artifact/references/vendor-cursor.md` etc.) are focused views into that same knowledge, scoped to what that skill needs.

When a vendor ships a change: run `vendor-sync`, confirm the diff, and the references stay authoritative.
