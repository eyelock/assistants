// No skill or template calls a seat's namespace private: every seat's memory is written at ynm's
// distributed level, so the whole team can read it (assistants #302).
import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");

function* files(dir) {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules") continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) yield* files(p);
    else if (/\.(md|sh|jq|json|mjs)$/.test(name) && name !== "CHANGELOG.md" && name !== "package.json" && name !== "namespace-wording.test.mjs") yield p;
  }
}

test("no skill or template calls a seat's memory a private home", () => {
  const hits = [];
  for (const dir of ["skills", "templates", "evals/files", "../../docs/wheelhouse"]) {
    try {
      for (const f of files(join(root, dir))) {
        readFileSync(f, "utf8").split("\n").forEach((line, i) => {
          if (/private home|no private|your private|private namespace/i.test(line)) hits.push(`${f}:${i + 1}: ${line.trim()}`);
        });
      }
    } catch (e) {
      if (e.code !== "ENOENT") throw e;
    }
  }
  assert.deepEqual(hits, []);
});
