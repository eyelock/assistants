// The vet-skill skill checks a pin by composing a probe harness with `ynd compose`: the include
// must resolve, in either output format, and its skills must be among the artifacts. Each case
// runs the real ynd against a probe whose includes are small local git repositories: one keeps
// its skill under skills/, the other at its top level, which resolves but yields nothing.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";

const hasYnd = spawnSync("ynd", ["--version"]).status === 0;
const dir = mkdtempSync(join(tmpdir(), "wheelhouse-vet-resolved-"));
after(() => rmSync(dir, { recursive: true, force: true }));

function repo(name, skillPath) {
  mkdirSync(join(dir, name, skillPath), { recursive: true });
  writeFileSync(join(dir, name, skillPath, "SKILL.md"), "---\nname: demo\ndescription: A demo skill.\n---\nHello.\n");
  const git = (...args) =>
    spawnSync("git", ["-C", join(dir, name), "-c", "user.name=t", "-c", "user.email=t@t", ...args]);
  git("init", "-q");
  git("add", "-A");
  git("commit", "-qm", "init");
}

function compose(...args) {
  const harness = join(dir, "probe");
  mkdirSync(join(harness, ".agents", "harness"), { recursive: true });
  const includes = [{ git: "../nested", pick: ["skills/demo"] }, { git: "../flat" }];
  writeFileSync(
    join(harness, ".agents", "harness", "plugin.json"),
    JSON.stringify({ name: "probe", version: "0.1.0", description: "probe", includes }),
  );
  const run = spawnSync("ynd", ["compose", ".", ...args], { cwd: harness, encoding: "utf8" });
  assert.equal(run.status, 0, run.stderr || run.stdout);
  return run.stdout;
}

if (hasYnd) {
  repo("nested", join("skills", "demo"));
  repo("flat", "demo");
}

test("text marks each resolved include [resolved] and lists only the nested skill", { skip: !hasYnd && "no ynd" }, () => {
  const out = compose("--format", "text");
  assert.match(out, /^\s*\.\.\/nested\s+pick=\[skills\/demo\]\s+\[resolved\]$/m);
  assert.match(out, /^\s*\.\.\/flat\s+\[resolved\]$/m);
  assert.match(out, /^\s*skill\s+demo\s+\.\.\/nested$/m);
  assert.doesNotMatch(out, /^\s*skill\s+\S+\s+\.\.\/flat$/m);
});

test('JSON gives each resolved include "resolved": true and lists only the nested skill', { skip: !hasYnd && "no ynd" }, () => {
  const out = JSON.parse(compose());
  assert.deepEqual(
    out.includes.map(({ git, resolved }) => [git, resolved]),
    [
      ["../nested", true],
      ["../flat", true],
    ],
  );
  assert.deepEqual(out.artifacts.skills, [{ name: "demo", source: "../nested" }]);
});
