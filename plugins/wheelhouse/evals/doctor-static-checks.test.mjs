// static-checks.sh holds the doctor's checks of a Wheelhouse's own files (no forked plugin scripts, every seat
// started by its own name, one default human, no Beads agent setup). check.sh adds them to its report and the
// rule sensors run them, so the two must report the same checks.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const doctor = join(plugin, "skills", "doctor", "scripts");
const clean = join(plugin, "sensors", "fixtures", "clean");
const NAMES = ["default human", "no Beads agent setup", "plugin script copies", "seats wired"];

const json = (cmd, args) => JSON.parse(spawnSync(cmd, args, { encoding: "utf8" }).stdout);

test("static-checks.sh reports the four file checks, all ok on the clean fixture", () => {
  const checks = json("bash", [join(doctor, "static-checks.sh"), "--dir", clean]);
  assert.deepEqual(checks.map((c) => c.name).sort(), NAMES);
  assert.ok(
    checks.every((c) => c.ok),
    JSON.stringify(checks),
  );
});

test("static-checks.sh and the doctor's check.sh report the same four checks", () => {
  const own = json("bash", [join(doctor, "static-checks.sh"), "--dir", clean]);
  const report = json("bash", [join(doctor, "check.sh"), "--dir", clean]);
  for (const c of own) {
    assert.deepEqual(
      report.checks.find((x) => x.name === c.name),
      c,
    );
  }
});

test("static-checks.sh refuses a directory that is not there", () => {
  const r = spawnSync("bash", [join(doctor, "static-checks.sh"), "--dir", join(clean, "nope")], {
    encoding: "utf8",
  });
  assert.equal(r.status, 2);
});
