# Testing and CI

How this repo checks what is in it. Most checks are free and run in CI on every pull request;
evals run a model, so they cost money and run only when you start them.

| Check | What it proves | Where it runs |
|---|---|---|
| `pnpm test` | every skill has evals, harnesses and the triage list agree, every docs link works | CI and locally |
| `pnpm lint` | code is formatted and linted (Biome), and skills and harnesses are well formed (`ynd lint`, `ynd validate`) | CI and locally |
| `pnpm lint:spell` | no misspelling in any Markdown file | CI and locally |
| `pnpm sync-manifests:check` | the marketplace indexes and plugin versions agree | CI and locally |
| `changeset status` | a pull request that changes a package carries a changeset | CI |
| SkillSpector | no skill a pull request changes has an unaccepted security finding | CI, and `make skillspector` |
| `make test-tutorials` | every tutorial that opts in runs start to finish on its free path | locally |
| `make evals` | each skill does better with it than without it, judged by a model | locally, on your Claude Code login |

`pnpm check` runs the free checks CI runs, except SkillSpector and the changeset check.

## How-to guides

- [Run evals](run-evals.md)
- [Run SkillSpector](run-skillspector.md): the security scan CI runs.
