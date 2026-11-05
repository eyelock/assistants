// Every ynh harness that includes a skills package from this repository must
// pick skills that exist here: a renamed or missing skill would otherwise only
// fail when someone installs the harness.
import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const ynh = join(root, "ynh");

const harnesses = readdirSync(ynh).filter((name) =>
  existsSync(join(ynh, name, ".agents", "harness", "plugin.json")),
);

for (const name of harnesses) {
  const manifest = JSON.parse(
    readFileSync(join(ynh, name, ".agents", "harness", "plugin.json"), "utf8"),
  );
  for (const include of manifest.includes ?? []) {
    if (!include.git?.includes("eyelock/assistants") || !include.path) continue;
    test(`ynh/${name} includes ${include.path} with skills that exist`, () => {
      const skillsDir = join(root, include.path, "skills");
      assert.ok(
        existsSync(skillsDir) && statSync(skillsDir).isDirectory(),
        `${include.path} has no skills/ directory`,
      );
      for (const pick of include.pick ?? []) {
        const skill = pick.replace(/^skills\//, "");
        assert.ok(
          existsSync(join(skillsDir, skill, "SKILL.md")),
          `${include.path}/skills/${skill}/SKILL.md is missing (picked by ynh/${name})`,
        );
      }
    });
  }
}
