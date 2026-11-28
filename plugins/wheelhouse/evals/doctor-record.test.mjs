// The doctor's record half reads the patrol's stored record-sensor results (.wheelhouse/record-sensors.json),
// runs no sensor, and says plainly when there are no results. Each case runs the real check.sh in a small
// Beads-memory Wheelhouse with bd stubbed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const bdStub = `#!/bin/sh
case "$1" in
  version) echo "bd version 1.3.2 (stub)" ;;
  memories) echo '{"schema_version":1}' ;;
  dolt) echo '[{"name":"origin"}]' ;;
  config) echo '{"value":"true"}' ;;
  *) echo '[]' ;;
esac
`;

function wheelhouse() {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-doctor-record-"));
  const wh = join(dir, "wh");
  const bin = join(dir, "bin");
  mkdirSync(bin);
  mkdirSync(join(wh, ".beads"), { recursive: true });
  spawnSync("git", ["init", "-q", "-b", "main", wh]);
  for (const t of ["jq", "git"]) {
    const found = spawnSync("sh", ["-c", `command -v ${t}`], { encoding: "utf8" }).stdout.trim();
    symlinkSync(found, join(bin, t));
  }
  writeFileSync(join(bin, "bd"), bdStub);
  chmodSync(join(bin, "bd"), 0o755);
  const skills = join(dir, "skills");
  for (const [skill, names] of [
    ["doctor", ["check.sh", "memory-checks.sh"]],
    ["work-graph", ["wheelhouse-lib.sh", "inbox.sh", "memory.sh"]],
  ]) {
    mkdirSync(join(skills, skill, "scripts"), { recursive: true });
    for (const n of names)
      copyFileSync(join(plugin, "skills", skill, "scripts", n), join(skills, skill, "scripts", n));
  }
  writeFileSync(join(wh, "wheelhouse.json"), JSON.stringify({ memory: "beads" }));
  const bash = spawnSync("sh", ["-c", "command -v bash"], { encoding: "utf8" }).stdout.trim();
  return {
    wh,
    results(obj) {
      mkdirSync(join(wh, ".wheelhouse"), { recursive: true });
      writeFileSync(
        join(wh, ".wheelhouse/record-sensors.json"),
        typeof obj === "string" ? obj : JSON.stringify(obj),
      );
    },
    record() {
      const out = spawnSync(bash, [join(skills, "doctor/scripts/check.sh"), "--dir", wh], {
        encoding: "utf8",
        env: { PATH: `${bin}:/usr/bin:/bin`, HOME: dir },
      });
      assert.equal(out.status, 0, out.stderr);
      return JSON.parse(out.stdout).checks.find((c) => c.name === "record sensors");
    },
    done: () => rmSync(dir, { recursive: true, force: true }),
  };
}

const now = () => Math.floor(Date.now() / 1000);

test("no stored results: says no patrol has run, and does not call the record clean", () => {
  const w = wheelhouse();
  try {
    const c = w.record();
    assert.equal(c.level, "info");
    assert.match(c.detail, /no patrol has run yet/);
    assert.match(c.detail, /not a clean record/);
    assert.doesNotMatch(c.detail, /counted zero/);
  } finally {
    w.done();
  }
});

test("fresh results with every sensor at zero are reported clean", () => {
  const w = wheelhouse();
  try {
    w.results({ at: now() - 60, interval_minutes: 5, sensors: { a: { count: 0, lines: [] } } });
    const c = w.record();
    assert.equal(c.ok, true);
    assert.match(c.detail, /every sensor counted zero/);
  } finally {
    w.done();
  }
});

test("a sensor above zero is a warning naming it and its count", () => {
  const w = wheelhouse();
  try {
    w.results({
      at: now(),
      interval_minutes: 5,
      sensors: { "stale-claims": { count: 3, lines: ["x"] }, ok: { count: 0, lines: [] } },
    });
    const c = w.record();
    assert.equal(c.ok, false);
    assert.equal(c.level, "warn");
    assert.match(c.detail, /above zero: stale-claims 3/);
    assert.doesNotMatch(c.detail, /ok 0/);
  } finally {
    w.done();
  }
});

test("a sensor that could not be counted is a warning, apart from a zero", () => {
  const w = wheelhouse();
  try {
    w.results({
      at: now(),
      interval_minutes: 5,
      sensors: { "merged-not-closed": { count: null, error: "gh is down", lines: [] } },
    });
    const c = w.record();
    assert.equal(c.ok, false);
    assert.match(c.detail, /could not be counted: merged-not-closed \(gh is down\)/);
    assert.doesNotMatch(c.detail, /above zero/);
  } finally {
    w.done();
  }
});

test("results older than twice the patrol's interval are a warning that the patrol may be down", () => {
  const w = wheelhouse();
  try {
    w.results({
      at: now() - 11 * 60,
      interval_minutes: 5,
      sensors: { a: { count: 0, lines: [] } },
    });
    const stale = w.record();
    assert.equal(stale.ok, false);
    assert.match(stale.detail, /11 minutes old, more than twice the patrol's 5-minute interval/);
    w.results({ at: now() - 9 * 60, interval_minutes: 5, sensors: { a: { count: 0, lines: [] } } });
    assert.equal(w.record().ok, true);
  } finally {
    w.done();
  }
});

test("a results file that is not JSON is a warning, not a crash", () => {
  const w = wheelhouse();
  try {
    w.results("not json");
    const c = w.record();
    assert.equal(c.ok, false);
    assert.match(c.detail, /could not be read/);
  } finally {
    w.done();
  }
});
