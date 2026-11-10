// The doctor and refresh check memory by backend: wheelhouse.json's "memory" key, read through
// memory.sh. For ynm they run ynm's checks; for Beads they check Beads' memory (readable, shared,
// seats born, assignees known) and never need ynm. Each case builds a small Wheelhouse in a scratch
// directory and runs the real check.sh or refresh.sh with ynm and bd stubbed on a PATH that holds
// only the tools the scripts need (so a Beads Wheelhouse really runs with no ynm installed).
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const checkSh = join(plugin, "skills", "doctor", "scripts", "check.sh");
const refreshSh = join(plugin, "skills", "refresh", "scripts", "refresh.sh");

// bd: a Wheelhouse database kept in $STUB_DIR. memories answers the map in memories.json (unless
// STUB_BAD_MEMORIES), dolt remote list answers [] unless STUB_REMOTE, list answers beads.json.
const bdStub = `#!/usr/bin/env node
const fs = require("node:fs");
const d = process.env.STUB_DIR;
const read = (f, dflt) => (fs.existsSync(d + "/" + f) ? fs.readFileSync(d + "/" + f, "utf8") : dflt);
const a = process.argv.slice(2).filter((x) => x !== "--readonly");
if (a[0] === "version") console.log("bd version 1.0.0 (stub)");
else if (a[0] === "memories") {
  if (process.env.STUB_BAD_MEMORIES) { console.error("dolt is down"); process.exit(1); }
  console.log(read("memories.json", "{}"));
} else if (a[0] === "dolt") console.log(process.env.STUB_REMOTE ? '[{"name":"origin"}]' : "[]");
else if (a[0] === "list") console.log(read("beads.json", "[]"));
else if (a[0] === "config") console.log('{"value":"true"}');
else console.log("[]");
`;

// ynm: a healthy, registered mount; recall answers a pinned identity for every seat but those in $UNBORN.
const ynmStub = `#!/bin/sh
case "$1" in
  --version) echo "@ynm/cli/0.5.0 darwin-arm64" ;;
  doctor) echo '{"checks":[{"name":"mount project (git-notes)","ok":true,"level":"info","detail":"here"},{"name":"pre-push hook","ok":true,"level":"info","detail":"syncs"},{"name":"client ynh","ok":true,"level":"info","detail":"registered"}]}' ;;
  recall)
    ns=""; prev=""
    for a in "$@"; do [ "$prev" = --namespace ] && ns="$a"; prev="$a"; done
    seat=\${ns#seat/}
    case " $UNBORN " in *" $seat "*) echo '[]' ;; *) printf '[{"namespace":"%s","pinned":true}]\\n' "$ns" ;; esac ;;
esac
`;

const SEATS = [
  ["hq", "desk", "."],
  ["eno", "crew", "harnesses/eno"],
  ["wick", "workers", "harnesses/wick"],
];
const IDENTITIES = Object.fromEntries(SEATS.map(([c]) => [`seat/${c}/identity`, `I am ${c}`]));

function wheelhouse({ memory, ynm = false, memories = IDENTITIES, beads = [] } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-doctor-memory-"));
  const wh = join(dir, "wh");
  const bin = join(dir, "bin");
  mkdirSync(bin);
  mkdirSync(wh);
  spawnSync("git", ["init", "-q", "-b", "main", wh]);
  for (const t of ["jq", "git", "node"]) {
    const found = spawnSync("sh", ["-c", `command -v ${t}`], { encoding: "utf8" }).stdout.trim();
    symlinkSync(found, join(bin, t));
  }
  writeFileSync(join(bin, "bd"), bdStub);
  chmodSync(join(bin, "bd"), 0o755);
  if (ynm) {
    writeFileSync(join(bin, "ynm"), ynmStub);
    chmodSync(join(bin, "ynm"), 0o755);
  }
  mkdirSync(join(wh, ".beads"));
  mkdirSync(join(wh, ".agents/harness"), { recursive: true });
  writeFileSync(join(wh, ".agents/harness/plugin.json"), JSON.stringify({ name: "hq", version: "0.1.0" }));
  mkdirSync(join(wh, "skills/roster/assets"), { recursive: true });
  writeFileSync(
    join(wh, "skills/roster/assets/roster.json"),
    JSON.stringify({
      seats: SEATS.map(([command, group, harness]) => ({ name: command, command, group, harness })),
      humans: [{ name: "Pat", command: "pat", default: true }],
    }),
  );
  if (memory !== undefined) writeFileSync(join(wh, "wheelhouse.json"), JSON.stringify({ memory }));
  writeFileSync(join(dir, "memories.json"), JSON.stringify({ schema_version: 1, ...memories }));
  writeFileSync(join(dir, "beads.json"), JSON.stringify(beads));
  const env = (extra = {}) => ({ PATH: `${bin}:/usr/bin:/bin`, HOME: dir, STUB_DIR: dir, UNBORN: "", ...extra });
  const bash = spawnSync("sh", ["-c", "command -v bash"], { encoding: "utf8" }).stdout.trim();
  return {
    dir,
    wh,
    check(extra = {}) {
      const out = spawnSync(bash, [checkSh, "--dir", wh], { encoding: "utf8", env: env(extra) });
      assert.equal(out.status, 0, out.stderr);
      const json = JSON.parse(out.stdout);
      return { json, by: (name) => json.checks.find((c) => c.name === name) };
    },
    refresh(extra = {}) {
      const out = spawnSync(bash, [refreshSh, "--dir", wh, "--doctor", "/nonexistent", "--dry-run"], { encoding: "utf8", env: env(extra) });
      assert.equal(out.status, 0, out.stderr);
      return JSON.parse(out.stdout);
    },
    done: () => rmSync(dir, { recursive: true, force: true }),
  };
}

test("beads memory: ynm is never checked, and a Wheelhouse with no ynm installed is fine", () => {
  const w = wheelhouse({ memory: "beads" });
  try {
    const r = w.check({ STUB_REMOTE: "1" });
    assert.equal(r.json.ok, true, JSON.stringify(r.json.checks.filter((c) => !c.ok)));
    assert.deepEqual(r.json.checks.filter((c) => /^ynm/.test(c.name) && c.name !== "ynm"), []);
    assert.equal(r.by("ynm installed"), undefined);
    assert.equal(r.by("memory backend").ok, true);
    assert.match(r.by("beads memory readable").detail, /3 memories/);
    assert.equal(r.by("beads memory shared").ok, true);
    assert.equal(r.by("seats born").ok, true);
  } finally {
    w.done();
  }
});

test("beads memory: no Dolt remote is a warning, an unreadable memory an error", () => {
  const w = wheelhouse({ memory: "beads" });
  try {
    const shared = w.check().by("beads memory shared");
    assert.equal(shared.ok, false);
    assert.equal(shared.level, "warn");
    const r = w.check({ STUB_BAD_MEMORIES: "1" });
    assert.equal(r.by("beads memory readable").level, "error");
    assert.equal(r.json.ok, false);
    assert.equal(r.by("seats born").ok, false);
    assert.match(r.by("seats born").detail, /couldn't recall/);
  } finally {
    w.done();
  }
});

test("beads memory: a seat with no identity key is not yet born", () => {
  const w = wheelhouse({ memory: "beads", memories: { "seat/hq/identity": "I am hq", "seat/eno/identity": "I am eno" } });
  try {
    const born = w.check({ STUB_REMOTE: "1" }).by("seats born");
    assert.equal(born.ok, false);
    assert.match(born.detail, /wick \(birth: the dispatcher\)/);
    assert.doesNotMatch(born.detail, /eno|hq/);
  } finally {
    w.done();
  }
});

test("beads memory: an assignee is known when memory holds a human/<command> key for them", () => {
  const bead = (id, assignee) => ({ id, status: "open", assignee, labels: [] });
  const w = wheelhouse({ memory: "beads", beads: [bead("w-1", "sam"), bead("w-2", "kit")], memories: { ...IDENTITIES, "human/sam/note/20261101T000000Z-eno": "hi" } });
  try {
    const known = w.check({ STUB_REMOTE: "1" }).by("assignees known");
    assert.equal(known.ok, false);
    assert.match(known.detail, /w-2 \(kit\)/);
    assert.doesNotMatch(known.detail, /w-1/);
  } finally {
    w.done();
  }
});

test("a bad wheelhouse.json is an error from the doctor", () => {
  const w = wheelhouse({ memory: "redis" });
  try {
    const r = w.check();
    assert.equal(r.by("memory backend").level, "error");
    assert.match(r.by("memory backend").detail, /ynm" or "beads"/);
    assert.equal(r.json.ok, false);
  } finally {
    w.done();
  }
});

test("ynm memory, by key or by default, runs ynm's checks and not Beads' memory checks", () => {
  for (const memory of [undefined, "ynm"]) {
    const w = wheelhouse({ memory, ynm: true });
    try {
      const r = w.check({ STUB_REMOTE: "1" });
      assert.equal(r.by("ynm installed").ok, true);
      assert.equal(r.by("ynm distributed mount").ok, true);
      assert.equal(r.by("beads memory readable"), undefined);
      assert.equal(r.by("beads memory shared"), undefined);
      assert.equal(r.by("seats born").ok, true);
      const unborn = w.check({ UNBORN: "wick" }).by("seats born");
      assert.equal(unborn.ok, false);
      assert.match(unborn.detail, /wick/);
    } finally {
      w.done();
    }
  }
});

test("ynm memory without ynm installed is still an error", () => {
  const w = wheelhouse({ memory: "ynm" });
  try {
    const r = w.check();
    assert.equal(r.by("ynm installed").level, "error");
    assert.equal(r.json.ok, false);
  } finally {
    w.done();
  }
});

test("refresh reports a seat with no identity, reading Beads memory when that is the backend", () => {
  const w = wheelhouse({ memory: "beads", memories: { "seat/hq/identity": "I am hq", "seat/eno/identity": "I am eno" } });
  try {
    const r = w.refresh();
    assert.deepEqual(r.seatsNotReady.map((s) => [s.seat, s.born]), [["wick", false]]);
    assert.match(r.seatsNotReady[0].reminder, /dispatcher/);
  } finally {
    w.done();
  }
});

test("refresh finds every seat born when Beads holds all their identities", () => {
  const w = wheelhouse({ memory: "beads" });
  try {
    assert.deepEqual(w.refresh().seatsNotReady, []);
  } finally {
    w.done();
  }
});

test("refresh reads ynm for the ynm backend", () => {
  const w = wheelhouse({ ynm: true });
  try {
    assert.deepEqual(w.refresh().seatsNotReady, []);
    assert.deepEqual(w.refresh({ UNBORN: "eno" }).seatsNotReady.map((s) => s.seat), ["eno"]);
  } finally {
    w.done();
  }
});

test("a seat that picks skills but not work-graph is warned, the desk and a seat that picks it are not", () => {
  const w = wheelhouse({ memory: "beads" });
  try {
    const harness = (cmd, includes) => {
      const dir = join(w.wh, cmd === "hq" ? "." : `harnesses/${cmd}`, ".agents/harness");
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, "plugin.json"), JSON.stringify({ name: "hq", version: "0.1.0", includes }));
    };
    harness("hq", [{ git: "../..", path: "plugins/wheelhouse" }]);
    harness("eno", [{ git: "../..", pick: ["skills/wake", "skills/work-graph"] }]);
    harness("wick", [{ git: "../..", pick: ["skills/wake", "skills/doctor"] }]);
    const bad = w.check({ STUB_REMOTE: "1" }).by("seats pick work-graph");
    assert.equal(bad.ok, false);
    assert.equal(bad.level, "warn");
    assert.match(bad.detail, /: wick$/);
    harness("wick", [{ git: "../..", pick: ["skills/wake", "skills/work-graph"] }]);
    assert.equal(w.check({ STUB_REMOTE: "1" }).by("seats pick work-graph").ok, true);
  } finally {
    w.done();
  }
});
