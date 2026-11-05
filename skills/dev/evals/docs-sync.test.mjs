// docs-sync's helper lists the docs a change may have made wrong. Each case builds a small
// repository with the eval fixtures (a Go CLI and a TypeScript library, each with a branch that
// leaves docs behind) and runs the real doc-candidates.sh against it.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const script = join(here, "..", "skills", "docs-sync", "scripts", "doc-candidates.sh");

function candidates(fixture, args = [], after = "") {
  const dir = mkdtempSync(join(tmpdir(), "docs-sync-"));
  try {
    const setup = spawnSync("bash", [join(here, "files", fixture)], { cwd: dir, encoding: "utf8" });
    assert.equal(setup.status, 0, setup.stderr);
    if (after) assert.equal(spawnSync("bash", ["-c", after], { cwd: dir }).status, 0);
    const out = spawnSync("bash", [script, ...args], { cwd: dir, encoding: "utf8" });
    return { ...out, json: out.status === 0 ? JSON.parse(out.stdout) : null };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const doc = (json, path) => json.docs.find((d) => d.path === path);

test("Go layout: renamed flag, new env var, and the docs and help text that name them", () => {
  const { status, stderr, json } = candidates("docs-sync-go.sh");
  assert.equal(status, 0, stderr);
  const terms = Object.fromEntries(json.terms.map((t) => [t.term, t]));
  assert.deepEqual([terms["--dry-run"].status, terms["--dry-run"].inCode], ["removed", false]);
  assert.deepEqual([terms["--check"].status, terms["--check"].inCode], ["added", true]);
  assert.equal(terms.TOOL_STORE_PATH.kind, "env");
  assert.deepEqual(json.files.code.sort(), ["cmd/tool/sync.go", "internal/store/path.go"]);

  assert.equal(doc(json, "docs/reference.md").kind, "reference");
  assert.ok(doc(json, "docs/reference.md").hits.some((h) => h.term === "--dry-run" && h.line === 7));
  const tutorial = doc(json, "docs/tutorial/first-sync.md");
  assert.equal(tutorial.kind, "tutorial");
  assert.ok(tutorial.caveats.some((c) => /Known issue/.test(c.text)), "the fixed defect's caveat is listed");
  const help = doc(json, "cmd/tool/sync.go");
  assert.deepEqual([help.kind, help.changed], ["help", true]);
});

test("never reads .env, even one tracked and changed on the branch", () => {
  const tracked = "printf 'TOOL_API_KEY=changed-secret-1111\\n' > .env && git add -f .env && git commit -qm env";
  const { status, stdout } = candidates("docs-sync-go.sh", [], tracked);
  assert.equal(status, 0);
  assert.doesNotMatch(stdout, /\.env|TOOL_API_KEY|not-a-real-key|changed-secret/);
});

test("TypeScript layout: a renamed export, and the README that still uses the old name", () => {
  const { status, stderr, json } = candidates("docs-sync-ts.sh");
  assert.equal(status, 0, stderr);
  const terms = Object.fromEntries(json.terms.map((t) => [t.term, t]));
  assert.deepEqual([terms.parseConfig.status, terms.parseConfig.inCode], ["removed", false]);
  assert.equal(terms.loadConfig.status, "added");
  assert.ok(doc(json, "README.md").hits.some((h) => h.term === "parseConfig"));
  assert.deepEqual(json.files.docs, ["docs/api.md"], "the doc the branch did update is marked as changed");
  assert.equal(doc(json, "docs/api.md").changed, true);
});

test("--base, and refusals", () => {
  const same = candidates("docs-sync-ts.sh", ["--base", "HEAD"]);
  assert.equal(same.status, 0, same.stderr);
  assert.deepEqual([same.json.terms, same.json.docs], [[], []]);
  assert.equal(candidates("docs-sync-ts.sh", ["--base", "no-such-ref"]).status, 1);
  assert.equal(candidates("docs-sync-ts.sh", ["--bogus"]).status, 1);
});
