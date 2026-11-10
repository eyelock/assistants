// A seat on trial is not in the roster until the trial ends, so its wake reads its own harness
// from the trial branch; a seat with neither a roster entry nor a harness is still refused.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const wakeSrc = join(plugin, "skills", "wake", "scripts", "wake.sh");
const memorySrc = join(plugin, "skills", "work-graph", "scripts", "memory.sh");
const roster = { seats: [{ name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "x" }], humans: [] };

function wake(seat) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-trial-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "harnesses", "zed"), { recursive: true });
    writeFileSync(join(dir, "harnesses", "zed", "AGENTS.md"), "# Zed\n\n**Mandate:** Try things out.\n");
    mkdirSync(join(dir, "scripts"));
    writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
    writeFileSync(join(dir, "scripts", "memory.sh"), readFileSync(memorySrc));
    writeFileSync(join(dir, "scripts", "wheelhouse-lib.sh"), readFileSync(join(plugin, "lib", "wheelhouse-lib.sh")));
    mkdirSync(join(dir, "bin"));
    for (const name of ["bd", "ynm"]) {
      writeFileSync(join(dir, "bin", name), "#!/bin/sh\necho '[]'\n");
      chmodSync(join(dir, "bin", name), 0o755);
    }
    return spawnSync("bash", [join(dir, "scripts", "wake.sh"), "--seat", seat, "--format", "json", "--no-sync"], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "" },
    });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("a seat on trial wakes from its own harness", () => {
  const r = wake("zed");
  assert.equal(r.status, 0, r.stderr);
  const out = JSON.parse(r.stdout);
  assert.equal(out.group, "trial");
  assert.equal(out.mandate, "Try things out.");
});

test("a seat with no roster entry and no harness is refused", () => {
  const r = wake("nobody");
  assert.equal(r.status, 1);
  assert.match(r.stderr, /not a seat in the roster/);
});
