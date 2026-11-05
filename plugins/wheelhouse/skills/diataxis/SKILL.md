---
name: diataxis
description: Write, restructure and review documentation with the Diataxis framework - tutorials, how-to guides, reference and explanation, each page exactly one kind. Use when writing or editing any documentation, deciding which kind a page is, splitting a page that mixes kinds, or reviewing docs for structure.
allowed-tools: Read Grep Glob Edit Write
---

# Diataxis

Diataxis, by Daniele Procida, sorts documentation by what the reader needs. Every page you write
or change is exactly one of four kinds. The framework text is pinned in this skill's `references/`
folder: read it there rather than from memory.

## The four kinds

| Kind | The reader is | The page | Its form |
|---|---|---|---|
| Tutorial | learning, by doing | a lesson that leads a beginner through an experience to a result | "we" and steps, one safe path, no choices |
| How-to guide | working, with a goal in mind | directions to reach a stated goal | a title that says the goal, steps, no teaching |
| Reference | working, needing a fact | neutral, complete description of the thing | structured like the thing, no instruction or opinion |
| Explanation | studying, wanting to understand | the why: context, reasons, alternatives | discussion, no steps and no lookup tables |

## Never mix kinds in one page

A page is one kind. When a draft drifts into another kind, do not blend it in: cut that part and
link to a page of the right kind, writing that page if it is missing. A tutorial that stops to
explain, a how-to guide that teaches, a reference that advises, and an explanation that lists steps
are the usual faults.

To decide a page's kind, use the compass in `references/compass.rst`: does it inform action or
cognition, and does it serve acquisition of skill or its application.

## The Wheelhouse house rule: as specific as possible

Whatever the kind, our docs are as specific as they can be:

- exact commands, as they are typed, not a description of them;
- full paths to files on the machine, such as `/home/sam/work/widget/AGENTS.md`, not relative ones,
  except in code and config, which keep portable relative paths;
- pull requests, issues and other web resources by short name and as a link, such as
  `[widget #12](https://github.com/example/widget/pull/12)`, never a bare number or URL.

## Where to look for which kind

The pages in `references/` are the pinned source (see `ATTRIBUTION.md`). Read the one you need:

- To see the framework in brief and how to start, read `references/start-here.rst` and `references/index.rst`.
- To tell which kind a page is, read `references/compass.rst` and `references/map.rst`.
- To write a tutorial, read `references/tutorials.rst`, and `references/tutorials-how-to.rst` for how it differs from a how-to guide.
- To write a how-to guide, read `references/how-to-guides.rst` and `references/tutorials-how-to.rst`.
- To write reference, read `references/reference.rst`, and `references/reference-explanation.rst` for how it differs from explanation.
- To write explanation, read `references/explanation.rst` and `references/reference-explanation.rst`.
- To use the framework on a real body of documentation, read `references/how-to-use-diataxis.rst`; the same folder holds a further page on putting Diataxis into practice, found with Glob.
- For the reasons behind it, read `references/theory.rst`, `references/foundations.rst` and `references/quality.rst`.

`references/` holds one further page that is not listed above; find it with Glob. Use Grep and Glob on `references/` to find a term, and Read the page before relying on it.

## Working method

1. Name the reader and what they need, then pick the one kind.
2. Read the matching page in `references/`.
3. Write or edit the page, keeping to that kind and to the house rule above.
4. Check the finished page for any sentence of another kind and move it out.

Do not edit the files in `references/`: they are copied unmodified and are share-alike licensed.
