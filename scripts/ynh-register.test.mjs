// Self-test for scripts/ynh-register.sh (run via `pnpm test` / `node --test scripts/`).
// Each test builds a throwaway pnpm workspace fixture mimicking this repo's
// layout and runs the real script against it, so nothing here touches the
// actual workspace. Requires bash, node and pnpm on PATH — same toolchain CI
// and local development already need.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const SCRIPT = resolve(dirname(fileURLToPath(import.meta.url)), "ynh-register.sh");

// Exercises every URL form the registration script must normalize (https,
// scheme-less, scp-style + .git, trailing slash), a duplicate include, a
// profile-level include, and two other-repo includes that must be ignored.
const DEFAULT_MANIFEST = {
  name: "sample",
  version: "0.2.0",
  description: "Sample harness for ynh-register tests.",
  default_vendor: "claude",
  profiles: {
    thorough: {
      includes: [{ git: "HTTPS://GitHub.com/Eyelock/Assistants/", path: "skills/pause" }],
    },
  },
  includes: [
    { git: "https://github.com/eyelock/assistants", path: "plugins/gitflow" },
    { git: "github.com/eyelock/assistants", path: "skills/dev", pick: ["skills/dev-quality"] },
    { git: "git@github.com:eyelock/assistants.git", path: "skills/tech" },
    { git: "https://github.com/eyelock/assistants", path: "skills/dev" },
    { git: "https://github.com/Jeffallan/claude-skills", pick: ["skills/golang-pro"] },
    { git: "https://github.com/eyelock/ynh", path: "docs" },
  ],
};

const EXPECTED_DEPENDENCIES = {
  "@eyelock-assistants/gitflow": "workspace:*",
  "@eyelock-assistants/dev-skills": "workspace:*",
  "@eyelock-assistants/tech-skills": "workspace:*",
  "@eyelock-assistants/pause-skills": "workspace:*",
};

function writeJson(path, data) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(data, null, 2)}\n`);
}

function makeFixture(t, options = {}) {
  const {
    manifest = DEFAULT_MANIFEST,
    workspaceGlobs = ["plugins/*", "skills/*", "ynh/*"],
    harnessDir = "ynh/sample",
  } = options;
  const root = mkdtempSync(join(tmpdir(), "ynh-register-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  writeFileSync(
    join(root, "pnpm-workspace.yaml"),
    `packages:\n${workspaceGlobs.map((g) => `  - "${g}"`).join("\n")}\n`,
  );
  writeJson(join(root, "package.json"), { name: "fixture-root", version: "0.0.0", private: true });
  for (const [dir, name] of [
    ["plugins/gitflow", "@eyelock-assistants/gitflow"],
    ["skills/dev", "@eyelock-assistants/dev-skills"],
    ["skills/tech", "@eyelock-assistants/tech-skills"],
    ["skills/pause", "@eyelock-assistants/pause-skills"],
  ]) {
    writeJson(join(root, dir, "package.json"), { name, version: "0.1.0", private: true });
  }
  writeJson(join(root, harnessDir, ".ynh-plugin", "plugin.json"), manifest);
  return root;
}

function runRegister(root, args) {
  return spawnSync("bash", [SCRIPT, ...args], { cwd: root, encoding: "utf8" });
}

function readWrapper(root, harnessDir = "ynh/sample") {
  return JSON.parse(readFileSync(join(root, harnessDir, "package.json"), "utf8"));
}

test("fresh `new` registration writes the wrapper and lockfile", (t) => {
  const root = makeFixture(t);
  const result = runRegister(root, ["ynh/sample", "new"]);
  assert.equal(result.status, 0, result.stderr);

  const wrapper = readWrapper(root);
  assert.deepEqual(wrapper, {
    name: "@eyelock-assistants/sample",
    version: "0.2.0",
    private: true,
    description: "Sample harness for ynh-register tests.",
    dependencies: EXPECTED_DEPENDENCIES,
  });
  // Canonical key order, and dependencies in include order (top-level
  // includes first, then profile includes; duplicates and other-repo
  // includes dropped).
  assert.deepEqual(Object.keys(wrapper), [
    "name",
    "version",
    "private",
    "description",
    "dependencies",
  ]);
  assert.deepEqual(Object.keys(wrapper.dependencies), Object.keys(EXPECTED_DEPENDENCIES));
  assert.ok(existsSync(join(root, "pnpm-lock.yaml")), "pnpm-lock.yaml should be written");
});

test("`update` regenerates generated keys but preserves hand-added ones", (t) => {
  const root = makeFixture(t);
  writeJson(join(root, "ynh/sample/package.json"), {
    name: "@eyelock-assistants/stale-name",
    version: "0.0.1",
    private: true,
    description: "stale description",
    dependencies: { "@eyelock-assistants/stale-dep": "workspace:*" },
    license: "MIT",
    scripts: { hello: "echo hi" },
  });
  const result = runRegister(root, ["ynh/sample", "update"]);
  assert.equal(result.status, 0, result.stderr);

  const wrapper = readWrapper(root);
  assert.equal(wrapper.name, "@eyelock-assistants/sample");
  assert.equal(wrapper.version, "0.2.0");
  assert.equal(wrapper.description, "Sample harness for ynh-register tests.");
  assert.deepEqual(wrapper.dependencies, EXPECTED_DEPENDENCIES);
  assert.equal(wrapper.license, "MIT");
  assert.deepEqual(wrapper.scripts, { hello: "echo hi" });
  assert.deepEqual(Object.keys(wrapper), [
    "name",
    "version",
    "private",
    "description",
    "dependencies",
    "license",
    "scripts",
  ]);
});

test("running twice is idempotent", (t) => {
  const root = makeFixture(t);
  const first = runRegister(root, ["ynh/sample", "new"]);
  assert.equal(first.status, 0, first.stderr);
  const wrapperAfterFirst = readFileSync(join(root, "ynh/sample/package.json"), "utf8");
  const lockAfterFirst = readFileSync(join(root, "pnpm-lock.yaml"), "utf8");

  const second = runRegister(root, ["ynh/sample", "update"]);
  assert.equal(second.status, 0, second.stderr);
  assert.match(second.stdout, /already up to date/);
  assert.equal(readFileSync(join(root, "ynh/sample/package.json"), "utf8"), wrapperAfterFirst);
  assert.equal(readFileSync(join(root, "pnpm-lock.yaml"), "utf8"), lockAfterFirst);
});

test("fails when a same-repo include path has no package.json", (t) => {
  const manifest = {
    ...DEFAULT_MANIFEST,
    profiles: {},
    includes: [{ git: "https://github.com/eyelock/assistants", path: "skills/nope" }],
  };
  const root = makeFixture(t, { manifest });
  const result = runRegister(root, ["ynh/sample", "new"]);
  assert.equal(result.status, 2, result.stderr);
  assert.match(result.stderr, /skills\/nope/);
  assert.match(result.stderr, /package\.json/);
  assert.ok(!existsSync(join(root, "ynh/sample/package.json")), "wrapper should not be written");
});

test("fails when the harness dir is not covered by a workspace glob", (t) => {
  const root = makeFixture(t, { workspaceGlobs: ["plugins/*", "skills/*"] });
  const result = runRegister(root, ["ynh/sample", "new"]);
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /pnpm-workspace\.yaml/);
  assert.match(result.stderr, /"ynh\/\*"/);
});

test("validates its arguments", (t) => {
  const root = makeFixture(t);

  const noArgs = runRegister(root, []);
  assert.equal(noArgs.status, 1);
  assert.match(noArgs.stderr, /usage:/);

  const badMode = runRegister(root, ["ynh/sample", "republish"]);
  assert.equal(badMode.status, 1);
  assert.match(badMode.stderr, /new.*update/);

  const rootEmbedded = runRegister(root, [".", "new"]);
  assert.equal(rootEmbedded.status, 1);
  assert.match(rootEmbedded.stderr, /ynh\/<name>/);

  const missingDir = runRegister(root, ["ynh/absent", "new"]);
  assert.equal(missingDir.status, 2);
  assert.match(missingDir.stderr, /does not exist/);
});
