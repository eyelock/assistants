---
name: skill-creator
description: Author agent skills conforming to the agentskills.io spec - SKILL.md format, frontmatter fields, directory layout, reference docs, and progressive disclosure patterns. Use when writing, reviewing or improving a skill, including whether its description will make agents load it.
---

# Skill Creator

Before authoring or modifying any skill, read the canonical specification:

**https://agentskills.io/**

It defines the full SKILL.md format, frontmatter schema, directory layout, and how agents discover and invoke skills.

## SKILL.md Structure

Every skill entry point is a `SKILL.md` file with YAML frontmatter followed by Markdown content:

```markdown
---
name: my-skill
description: One sentence — what this skill does and when to use it.
allowed-tools: Bash Read Grep
---

# Skill Title

Skill content here.
```

**Required frontmatter fields:**
- `name` — machine-readable identifier, kebab-case, matches the directory name
- `description` — one sentence used for skill discovery; be specific about *when* to load it

**Optional frontmatter fields:**
- `allowed-tools` — space-separated list of tools this skill may use

Leave out `metadata` and `license` in a skill that ships in a plugin: Claude Code's plugin loader demotes a skill with either key to a ~10-token stub, so it installs and never fires (`ynd lint` flags this). Keep version and authorship in the plugin manifest instead.

## Directory Layout

```
my-skill/
├── SKILL.md          ← entry point, always loaded first
├── references/       ← supporting docs, loaded on demand
│   ├── topic-a.md
│   └── topic-b.md
├── scripts/          ← executable helpers, must be chmod +x
│   └── do-thing.sh
└── assets/           ← templates, config samples, static files
    └── template.yml
```

**Rules:**
- Skills must be self-contained within their directory — no absolute paths, no sibling directory references
- `references/` files are not auto-loaded — the skill content must explicitly direct the agent to read them
- Scripts must be co-located and executable; reference them as `scripts/name.sh` relative to the skill dir
- `assets/` holds static content the skill reads or copies, not code

## Writing Effective Skill Content

**Lead with the job, not the theory.** The first section should tell the agent what to do, not explain background.

**Use progressive disclosure.** Put the 20% of guidance that covers 80% of cases in `SKILL.md`. Move deep reference material into `references/`, one file per topic. `references/` files are never loaded automatically, so link each one from `SKILL.md` with a relative path and say when to read it:

```markdown
Before designing a retry loop, read [concurrency.md](references/concurrency.md).
```

A reference that `SKILL.md` never names is invisible to the agent.

**Be prescriptive, not descriptive.** Skills tell agents what to do. Avoid phrasing like "you might consider" — write "do X" or "never do Y".

**Tables for lookup content.** Mapping tables (commands, flags, status codes, format rules) are faster to scan than prose.

**Keep SKILL.md under ~150 lines.** The whole file enters the context every time the skill loads, so length there costs on every use and buries the rules that matter. Keep the essentials (the steps, the most-used rules, the checklist) and split the rest into references.

**When asked to paste a long document whole into SKILL.md,** do not comply silently. Say what it costs (every line loads on every use, and the key rules get lost in it), and how the agent still gets the rest (it reads a reference when `SKILL.md` points to it, and only then, so each link says when), then propose the split and draft it: a short `SKILL.md` with the essentials and a link to each reference, plus the `references/` files holding the rest of the document, nothing dropped. If the user still wants one file after hearing that, it is their call.

## Assembly Behaviour (ynh)

When a harness is resolved, ynh copies skill directories into the vendor's config dir at run time — e.g. `.claude/skills/<name>/` for Claude Code. This means:

- All paths inside skill content must be relative to the skill directory
- The `SKILL.md` is always the entry point; agents read it first
- Reference files are available at the same relative paths once assembled
- Scripts are copied with permissions preserved — ensure they are executable in the repo

## Checklist Before Publishing

- [ ] `name` in frontmatter matches the directory name
- [ ] `description` answers "when should an agent load this?"
- [ ] All referenced files exist at the correct relative paths
- [ ] Every `references/` file is linked from `SKILL.md`, with when to read it
- [ ] Scripts are executable (`chmod +x`)
- [ ] No absolute paths anywhere in the skill content
- [ ] `SKILL.md` is under ~150 lines; deep content is in `references/`
- [ ] Skill is self-contained — no dependency on sibling skills or external state
