// sync-manifests.mjs must find a package's source manifest wherever it lives, so that
// writeback and the drift check cover ynh harnesses, whose manifest is only in
// .agents/harness/ (assistants #44), as well as plugins and .harness.json harnesses.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const script = join(dirname(fileURLToPath(import.meta.url)), "sync-manifests.mjs");

function tree(files) {
  const root = mkdtempSync(join(tmpdir(), "sync-manifests-"));
  for (const [path, data] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), `${JSON.stringify(data, null, 2)}\n`);
  }
  return root;
}

function run(root, mode) {
  return spawnSync("node", [script, mode], {
    env: { ...process.env, SYNC_MANIFESTS_ROOT: root },
    encoding: "utf8",
  });
}

const read = (root, path) => JSON.parse(readFileSync(join(root, path), "utf8"));
const agents = (name, version, extra = {}) => ({ name, version, description: name, ...extra });
const pkg = (name, version, extra = {}) => ({
  name: `@eyelock-assistants/${name}`,
  version,
  private: true,
  description: name,
  ...extra,
});

test("check fails when a ynh harness manifest in .agents/harness/ lags its package", () => {
  const root = tree({
    "ynh/termq-dev/.agents/harness/plugin.json": agents("termq-dev", "0.1.0"),
    "ynh/termq-dev/package.json": pkg("termq-dev", "0.3.0"),
  });
  try {
    const r = run(root, "check");
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stderr, /ynh\/termq-dev\/package\.json: version out of sync/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("writeback copies the package version into the .agents/harness/ manifest", () => {
  const root = tree({
    "ynh/termq-dev/.agents/harness/plugin.json": agents("termq-dev", "0.1.0"),
    "ynh/termq-dev/package.json": pkg("termq-dev", "0.3.0"),
  });
  try {
    assert.equal(run(root, "writeback").status, 0);
    assert.equal(read(root, "ynh/termq-dev/.agents/harness/plugin.json").version, "0.3.0");
    assert.equal(run(root, "check").status, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a ynh harness that is in sync passes, whatever the order of its dependencies", () => {
  const root = tree({
    "skills/a/.claude-plugin/plugin.json": agents("a", "1.0.0"),
    "skills/b/.claude-plugin/plugin.json": agents("b", "1.0.0"),
    "ynh/h/.agents/harness/plugin.json": agents("h", "0.1.0", {
      includes: [{ path: "skills/a" }, { path: "skills/b" }],
    }),
    "skills/a/package.json": pkg("a", "1.0.0"),
    "skills/b/package.json": pkg("b", "1.0.0"),
    "ynh/h/package.json": pkg("h", "0.1.0", {
      dependencies: {
        "@eyelock-assistants/b": "workspace:*",
        "@eyelock-assistants/a": "workspace:*",
      },
    }),
  });
  try {
    const r = run(root, "check");
    assert.equal(r.status, 0, r.stdout + r.stderr);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a plugin keeps .claude-plugin/plugin.json as its source and mirrors into .agents/harness/", () => {
  const root = tree({
    "plugins/p/.claude-plugin/plugin.json": agents("p", "1.0.0"),
    "plugins/p/.agents/harness/plugin.json": agents("p", "0.9.0"),
    "plugins/p/package.json": pkg("p", "1.0.0"),
  });
  try {
    const r = run(root, "check");
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(
      r.stderr,
      /plugins\/p\/\.agents\/harness\/plugin\.json version 0\.9\.0 != 1\.0\.0/,
    );
    assert.equal(run(root, "generate").status, 0);
    assert.equal(read(root, "plugins/p/.agents/harness/plugin.json").version, "1.0.0");
    assert.equal(run(root, "check").status, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
