// Every shell script the wheelhouse plugin ships is named by at least one test in this folder, so a
// new script (or one a split leaves behind) cannot land with no test coverage. The tests run the
// real scripts against stubs; this one only checks that each script is named.
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const evals = dirname(fileURLToPath(import.meta.url));
const skills = join(evals, "..", "skills");

const scripts = readdirSync(skills, { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .flatMap((d) => {
    const dir = join(skills, d.name, "scripts");
    try {
      return readdirSync(dir).filter((f) => f.endsWith(".sh"));
    } catch {
      return [];
    }
  });

const tests = readdirSync(evals)
  .filter((f) => f.endsWith(".test.mjs") && f !== "script-coverage.test.mjs")
  .map((f) => readFileSync(join(evals, f), "utf8"));

test("the plugin has scripts to cover", () => {
  assert.ok(scripts.length > 0);
});

for (const script of scripts) {
  test(`${script} is named by a test`, () => {
    const named = new RegExp(`(^|[^\\w-])${script.replace(/\./g, "\\.")}`);
    assert.ok(
      tests.some((t) => named.test(t)),
      `no test under plugins/wheelhouse/evals names ${script}: add one beside the others`,
    );
  });
}
