# Add a platform

Worked example: branch `feat/apple-calendar` (not yet merged). Replace `<p>` with the platform
id, for example `apple-calendar`.

1. Create the platform skill `skills/platforms/skills/<p>/` with:
   - `SKILL.md` (frontmatter `name` and `description`; read-only rules first)
   - `references/tools.md` and `references/triage.md`
   - `evals/evals.json` and `evals/eval_queries.json`
   - a fixture in `skills/platforms/evals/files/<p>-raw.json`
2. Create the harness `ynh/<p>/` with `.agents/harness/plugin.json` and `AGENTS.md`. Copy
   `ynh/google-calendar` for a server with a read-only flag, or `ynh/imessage` for profiles.
   Include `skills/triage` and pick `skills/<p>` from `skills/platforms`.
3. Declare the MCP server in `mcp_servers`, pin its version, and list credentials in
   `env_passthrough`. If the server can write, add a `before_tool` hook and a test for it
   (see `scripts/apple-calendar-guard.test.mjs` on that branch).
4. Add the platform to `platforms` in
   `skills/triage/skills/add-triage-question/assets/questions.json`, and to `on`, `todo` or
   `not_on` of every question.
5. Generate the manifests and the focuses:

   ```bash
   node skills/triage/skills/add-triage-question/scripts/triage-questions.mjs sync
   scripts/ynh-register.sh ynh/<p> new
   ```

6. Add a changeset in `.changeset/<p>.md`, and any new words to `.cspell/project-words.txt`.
7. Check:

   ```bash
   pnpm check
   make eval P=skills/platforms/skills/<p> DRY_RUN=1
   ```

`scripts/ynh-register.sh` writes `ynh/<p>/package.json` and refreshes `pnpm-lock.yaml`, per its
header. Not yet run for this recipe. `ynh/*` harnesses are not indexed by `pnpm sync-manifests`.
