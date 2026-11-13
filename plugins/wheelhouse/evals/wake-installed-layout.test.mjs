// The layout ynh installs is the only real one: wake.sh in the wake skill's scripts/ folder, with sync.sh and
// render-wake.jq beside it, and memory.sh and wheelhouse-lib.sh in the work-graph skill's. Every other wake eval
// copies the scripts into one flat folder; this one runs them where they sit, so a missing sync.sh or
// render-wake.jq (wake.sh exits 3 without either) is caught.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const roster = {
  seats: [{ name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build." }],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};

function installed() {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-layout-"));
  mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
  writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
  mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
  writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), "**Mandate:** Build one bead at a time.\n");
  for (const [skill, files] of [
    ["wake", ["wake.sh", "sync.sh", "render-wake.jq"]],
    ["work-graph", ["memory.sh", "wheelhouse-lib.sh"]],
  ]) {
    mkdirSync(join(dir, "plugin", "skills", skill, "scripts"), { recursive: true });
    for (const f of files) copyFileSync(join(plugin, "skills", skill, "scripts", f), join(dir, "plugin", "skills", skill, "scripts", f));
  }
  mkdirSync(join(dir, "bin"));
  for (const [name, body] of [["bd", "#!/bin/sh\necho '[]'\n"], ["ynm", "#!/bin/sh\necho '[]'\n"]]) {
    writeFileSync(join(dir, "bin", name), body);
    chmodSync(join(dir, "bin", name), 0o755);
  }
  return dir;
}

function wake(dir) {
  return spawnSync("bash", [join(dir, "plugin", "skills", "wake", "scripts", "wake.sh"), "--seat", "hynde", "--format", "text", "--no-sync"], {
    cwd: dir,
    encoding: "utf8",
    env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "" },
  });
}

test("wake.sh runs from the installed layout, with sync.sh and render-wake.jq beside it", () => {
  const dir = installed();
  try {
    const r = wake(dir);
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /# Waking: hynde/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

for (const missing of ["sync.sh", "render-wake.jq"]) {
  test(`wake.sh stops with exit 3 and names ${missing} when it is not beside it`, () => {
    const dir = installed();
    try {
      unlinkSync(join(dir, "plugin", "skills", "wake", "scripts", missing));
      const r = wake(dir);
      assert.equal(r.status, 3, r.stdout + r.stderr);
      assert.ok(r.stderr.includes(missing), r.stderr);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
}
