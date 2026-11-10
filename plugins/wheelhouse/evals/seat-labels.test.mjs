// Every harness, the desk's too, carries wheelhouse:<name> (the Wheelhouse's own name, the
// desk's) in its labels; the doctor warns about a harness without it or with another
// Wheelhouse's, and the skills that write harnesses say to write it. Each case runs the real
// check on a small Wheelhouse.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const checkSh = join(plugin, "skills", "doctor", "scripts", "check.sh");

const manifest = (name, labels) => ({ name, version: "0.1.0", ...(labels ? { labels } : {}) });

function withWheelhouse({ desk, seats }, fn) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-labels-"));
  try {
    const write = (path, json) => {
      mkdirSync(dirname(join(dir, path)), { recursive: true });
      writeFileSync(join(dir, path), JSON.stringify(json));
    };
    write(".agents/harness/plugin.json", desk);
    write("skills/roster/assets/roster.json", {
      seats: Object.keys(seats).map((c) => ({ name: c, group: "workers", command: c, harness: `harnesses/${c}`, mandate: "m" })),
    });
    for (const [c, m] of Object.entries(seats)) write(`harnesses/${c}/.agents/harness/plugin.json`, m);
    fn(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const labelled = (dir) => {
  const r = spawnSync("bash", [checkSh, "--dir", dir], { encoding: "utf8" });
  return JSON.parse(r.stdout).checks.find((c) => c.name === "seats labelled");
};

test("the doctor passes a desk and seats that all carry the Wheelhouse's label", () => {
  withWheelhouse(
    { desk: manifest("hq", { wheelhouse: "hq" }), seats: { okafor: manifest("okafor", { wheelhouse: "hq", team: "x" }) } },
    (dir) => {
      const c = labelled(dir);
      assert.equal(c.ok, true);
      assert.match(c.detail, /wheelhouse:hq/);
    },
  );
});

test("the doctor warns about a harness without the label, the desk's included, and says how to fix it", () => {
  withWheelhouse(
    { desk: manifest("hq"), seats: { okafor: manifest("okafor", { wheelhouse: "hq" }), gore: manifest("gore") } },
    (dir) => {
      const c = labelled(dir);
      assert.equal(c.ok, false);
      assert.equal(c.level, "warn");
      assert.match(c.detail, /desk/);
      assert.match(c.detail, /gore/);
      assert.doesNotMatch(c.detail, /okafor/);
      assert.match(c.fix, /"labels": \{"wheelhouse": "hq"\}/);
      assert.match(c.fix, /ynr query runs --label wheelhouse:hq/);
    },
  );
});

test("the doctor warns about a harness carrying another Wheelhouse's label", () => {
  withWheelhouse(
    { desk: manifest("hq", { wheelhouse: "hq" }), seats: { okafor: manifest("okafor", { wheelhouse: "other" }) } },
    (dir) => {
      const c = labelled(dir);
      assert.equal(c.ok, false);
      assert.match(c.detail, /another Wheelhouse's label: okafor/);
      assert.doesNotMatch(c.detail, /without the label/, "a wrong label is not also a missing one");
      assert.equal(c.detail.match(/okafor/g).length, 1, "the harness is listed once");
    },
  );
});

test("add-seat, create-wheelhouse and the doctor document the label, and name no Wheelhouse or human", () => {
  const read = (...p) => readFileSync(join(plugin, "skills", ...p), "utf8");
  assert.match(read("add-seat", "SKILL.md"), /"labels": \{ "wheelhouse": "<wheelhouse>" \}/);
  assert.match(read("create-wheelhouse", "SKILL.md"), /"labels": \{ "wheelhouse": "<name>" \}/);
  assert.match(read("doctor", "SKILL.md"), /ynr query runs --label wheelhouse:<name>/);
  for (const f of [["add-seat", "SKILL.md"], ["create-wheelhouse", "SKILL.md"], ["doctor", "SKILL.md"], ["doctor", "scripts", "check.sh"]]) {
    assert.doesNotMatch(read(...f), /wheelhouse:(ynw|hq)\b/, `${f.join("/")} names a Wheelhouse in a label`);
  }
});
