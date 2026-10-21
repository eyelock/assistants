# Add a triage question

Triage is one domain among several in this repo, and this page is only for it. To add any other skill, see [Add a skill to a plugin](add-a-skill-to-a-plugin.md).

First decide whether it belongs on the list. The criteria are in
`skills/triage/skills/add-triage-question/SKILL.md`. Most ideas should not be added.

1. Write the generic skill in `skills/triage/skills/<name>/`, with `SKILL.md`,
   `evals/evals.json` and `evals/eval_queries.json`. Copy the shape of `find`.
2. Add an entry to `skills/triage/skills/add-triage-question/assets/questions.json`: `id`,
   `skills`, `ask` (with `{at}` for the platform). Put every platform in exactly one of `on`,
   `todo`, or `not_on` with a reason.
3. For each platform in `on`, add a row for the question to
   `skills/platforms/skills/<platform>/references/triage.md`.
4. Write the focus into each harness, then format:

   ```bash
   node skills/triage/skills/add-triage-question/scripts/triage-questions.mjs sync
   pnpm exec biome format --write
   ```

5. Check the list and the harnesses agree:

   ```bash
   node skills/triage/skills/add-triage-question/scripts/triage-questions.mjs check
   pnpm test
   ```

6. Regenerate [Triage questions](../../use/reference/triage-questions.md) from `questions.json`
   (not yet scripted; edit by hand).

To move a platform from `todo` to `on`, do steps 3 to 5 for that platform alone.
