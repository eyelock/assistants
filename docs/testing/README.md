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
| actionlint | the workflow files are well formed | CI |
| shellcheck, whole repository | every shell script passes shellcheck at warning level and up | CI |
| Plugin scripts (wheelhouse) | every wheelhouse plugin script passes shellcheck at warning level and its tests (`node --test plugins/wheelhouse/evals/*.test.mjs`) pass, on Linux and macOS | CI |
| Plugin tests (media-management) | the plugin's script and hook tests (`make -C plugins/media-management test`) pass on macOS, under its stock bash 3.2, so its scripts must run there | CI, and locally on macOS |
| SkillSpector | no skill a pull request changes has an unaccepted security finding | CI, and `make skillspector` |
| `make test-tutorials` | every tutorial that opts in runs start to finish on its free path | locally |
| `make evals` | each skill does better with it than without it, judged by a model | locally, on your Claude Code login |

`pnpm check` runs the free checks CI runs, except actionlint, shellcheck, the plugin script and
plugin tests (they need their own tools), SkillSpector and the changeset check.

## How-to guides

- [Run evals](run-evals.md)
- [Run SkillSpector](run-skillspector.md): the security scan CI runs.

## Reference

- [Seat eval stubs and fixture](seat-eval-stubs.md): the `gh`, `git` and `bd` stubs and the test Wheelhouse a seat eval's setup uses.
