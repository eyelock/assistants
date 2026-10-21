# Add a skill to a plugin

Add a skill to an existing package in this repo, such as `skills/dev`, `skills/voice` or `plugins/gitflow`. To learn the parts first, follow [Write a skill with evals](../tutorials/write-a-skill-with-evals.md). Replace `<pkg>` with the package path (for example `skills/voice`) and `<name>` with the skill name.

1. Scaffold the skill from the package directory:

   ```bash
   cd <pkg>
   ynd create skill <name>
   ```

   This writes `skills/<name>/SKILL.md` with only `name` and `description` in the frontmatter. Packages keep skills in `<pkg>/skills/<name>/`.

2. Write the skill. Keep `name` equal to the folder name, make `description` say what it does and when to use it, and put long reference material in `references/` so `SKILL.md` stays short. Do not add `compatibility`, `license` or `metadata` frontmatter: `ynd lint` rejects them. See [Skill layout](../reference/skill-layout.md).

3. Add evals in `skills/<name>/evals/`: `evals.json` and `eval_queries.json`. `pnpm test` fails for a new skill without them. A fixture shared by several skills goes in the package's own `evals/files/`. A skill that runs commands needs a sandboxed case; see `plugins/gitflow/skills/push/evals/` and the Evals section of `AGENTS.md`.

4. Check it, from the repository root:

   ```bash
   ynd lint <pkg>
   ynd validate <pkg>
   make eval P=<pkg>/skills/<name> DRY_RUN=1
   make eval P=<pkg>/skills/<name>
   ```

   The last line runs the model and costs money; run it once the dry run looks right.

5. Add a changeset, `.changeset/<slug>.md`, naming the package as `package.json` in `<pkg>` does:

   ```md
   ---
   "@eyelock-assistants/<package-name>": minor
   ---

   Add the <name> skill: what it does, in one sentence.
   ```

   Run `pnpm changeset:status` to see it.

6. Update what counts skills. The package count in the root `README.md` repository tree (for example "9 skills") is written by hand. A harness that lists the package with `pick` only gets the new skill if you add `skills/<name>` to that `pick`; the other manifests stay as they are because a plugin discovers its own `skills/`.

7. Run the full gate:

   ```bash
   pnpm check
   ```

   It runs the manifest sync check, lint, format, spelling and tests. Add any new real words to `.cspell/project-words.txt`.

A skill in a **new** plugin also needs the three manifests (`.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.agents/harness/plugin.json`), an entry in each marketplace index, and a `package.json` that `pnpm sync-manifests` writes. See [Harness manifest](../reference/harness-manifest.md).
