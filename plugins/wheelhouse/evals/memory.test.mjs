// memory.sh is one memory wrapper over ynm or Beads, chosen by wheelhouse.json. Each case runs the
// real script in a scratch Wheelhouse with ynm and bd stubbed by small stateful node programs, and
// checks that both backends answer in the same JSON: [{id, kind, text, at, by, bead}], newest first.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const script = join(plugin, "skills", "work-graph", "scripts", "memory.sh");

// bd: remember --key K -- text, memories --json (a key-to-text map), forget K, dolt remote list.
const bdStub = `#!/usr/bin/env node
const fs = require("node:fs");
const f = process.env.STUB_DIR + "/bd.json";
const db = fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, "utf8")) : {};
const a = process.argv.slice(2).filter((x) => x !== "--readonly");
const log = (s) => fs.appendFileSync(process.env.STUB_DIR + "/calls.log", "bd " + s + "\\n");
log(a.join(" "));
if (process.env.STUB_FAIL === "bd") { console.error("dolt is down"); process.exit(1); }
if (a[0] === "remember") {
  const key = a[a.indexOf("--key") + 1];
  db[key] = a[a.indexOf("--") + 1];
  fs.writeFileSync(f, JSON.stringify(db));
} else if (a[0] === "memories") {
  console.log(JSON.stringify({ schema_version: 1, ...db }));
} else if (a[0] === "forget") {
  delete db[a[a.length - 1]];
  fs.writeFileSync(f, JSON.stringify(db));
} else if (a[0] === "dolt") {
  console.log(process.env.STUB_REMOTE ? '[{"name":"origin"}]' : "[]");
} else if (a[0] === "sync") {
  if (process.env.STUB_SYNC_FAIL) process.exit(1);
}
`;

// ynm: remember/supersede/pin/forget/recall/sync over a JSON list.
const ynmStub = `#!/usr/bin/env node
const fs = require("node:fs");
const f = process.env.STUB_DIR + "/ynm.json";
const db = fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, "utf8")) : [];
const a = process.argv.slice(2);
const opt = (n) => { const i = a.indexOf("--" + n); return i < 0 ? undefined : a[i + 1]; };
const save = () => fs.writeFileSync(f, JSON.stringify(db));
fs.appendFileSync(process.env.STUB_DIR + "/calls.log", "ynm " + a.join(" ") + "\\n");
if (process.env.STUB_FAIL === "ynm") { console.error("store locked"); process.exit(1); }
let n = db.length;
if (a[0] === "remember" || a[0] === "supersede") {
  if (a[0] === "supersede") { const o = db.find((m) => m.memoryId === opt("memory-id")); o.tombstoned = true; }
  const m = { memoryId: "M" + ++n, namespace: opt("namespace") ?? (a[0] === "supersede" ? db.find((x) => x.memoryId === opt("memory-id")).namespace : "common"),
    tags: (opt("tags") ?? "").split(","), subject: opt("subject"), content: opt("content"), level: opt("level"),
    data: JSON.parse(opt("data") ?? "{}"), updatedAt: new Date(Date.UTC(2026, 10, 1, 0, 0, n)).toISOString() };
  db.push(m); save(); console.log(JSON.stringify({ memoryId: m.memoryId }));
} else if (a[0] === "pin") { db.find((m) => m.memoryId === a[1]).pinned = true; save();
} else if (a[0] === "forget") { db.find((m) => m.memoryId === opt("memory-id")).tombstoned = true; save();
} else if (a[0] === "recall") {
  const ns = opt("namespace"), tags = opt("tags"), subj = opt("subject");
  // Like ynm's toIndexed: recall returns content with the memory's string data values (in key order,
  // joined by a space) appended after a newline, so memory.sh must strip that line.
  const shown = (m) => {
    const tail = Object.values(m.data ?? {}).filter((v) => typeof v === "string").join(" ");
    return tail ? { ...m, content: m.content + "\\n" + tail } : m;
  };
  console.log(JSON.stringify(db.filter((m) => !m.tombstoned && (!ns || m.namespace === ns) && (!subj || m.subject === subj) &&
    (!tags || tags.split(",").every((t) => m.tags.includes(t)))).reverse().map(shown)));
}
`;

function wheelhouse(memory, { remote = false } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-memory-"));
  mkdirSync(join(dir, "bin"));
  mkdirSync(join(dir, "stub"));
  for (const [name, body] of [["bd", bdStub], ["ynm", ynmStub]]) {
    writeFileSync(join(dir, "bin", name), body);
    chmodSync(join(dir, "bin", name), 0o755);
  }
  writeFileSync(join(dir, "bin", "git"), `#!/bin/sh\n${remote ? 'echo origin' : 'true'}\n`);
  chmodSync(join(dir, "bin", "git"), 0o755);
  if (memory) writeFileSync(join(dir, "wheelhouse.json"), JSON.stringify({ tasks: "beads", ...(memory === "-" ? {} : { memory }) }));
  const run = (args, extra = {}) =>
    spawnSync("bash", [script, ...args], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, STUB_DIR: join(dir, "stub"), ...extra },
    });
  const json = (args, extra) => {
    const r = run(args, extra);
    assert.equal(r.status, 0, r.stderr);
    return JSON.parse(r.stdout);
  };
  const calls = () => {
    try { return readFileSync(join(dir, "stub", "calls.log"), "utf8"); } catch { return ""; }
  };
  return { dir, run, json, calls, done: () => rmSync(dir, { recursive: true, force: true }) };
}

const story = (w) => {
  w.json(["remember", "--actor", "gahan", "--kind", "identity", "--seat", "gahan", "--text", "I am Gahan."]);
  w.json(["remember", "--actor", "gahan", "--kind", "identity", "--seat", "gahan", "--text", "I am Gahan, generalist."]);
  w.json(["remember", "--actor", "gahan", "--kind", "handoff", "--seat", "gahan", "--text", "Next: yjm0."]);
  w.json(["remember", "--actor", "marr", "--kind", "kudos", "--seat", "gahan", "--text", "Thanks for #160."]);
  w.json(["remember", "--actor", "gahan", "--kind", "close-note", "--seat", "gahan", "--bead", "ynw-1", "--text", "Surprised: a.\nSharp edges: b."]);
  w.json(["remember", "--actor", "marr", "--kind", "note", "--human", "stakker", "--text", "FYI: merged."]);
  w.json(["remember", "--actor", "gahan", "--kind", "fact", "--slug", "dolt-ports", "--text", "Dolt ports clash."]);
  w.json(["remember", "--actor", "gahan", "--kind", "event", "--bead", "ynw-1", "--text", "ynw-1: closed; the Linux build was skipped."]);
};

const SHAPE = ["at", "bead", "by", "id", "kind", "text"];

for (const [label, memory] of [["no wheelhouse.json", null], ["memory key missing", "-"], ["ynm", "ynm"], ["beads", "beads"]]) {
  const backend = memory === "beads" ? "beads" : "ynm";
  test(`${label}: backend is ${backend}`, () => {
    const w = wheelhouse(memory);
    try {
      assert.equal(w.run(["backend"]).stdout.trim(), backend);
    } finally {
      w.done();
    }
  });
}

for (const memory of ["ynm", "beads"]) {
  test(`${memory}: every kind round-trips in the one JSON shape, newest first`, () => {
    const w = wheelhouse(memory);
    try {
      story(w);
      const seat = w.json(["recall", "--seat", "gahan"]);
      assert.deepEqual(seat.map((m) => m.kind).sort(), ["close-note", "handoff", "identity", "kudos"]);
      for (const m of seat) assert.deepEqual(Object.keys(m).sort(), SHAPE);
      const ats = seat.map((m) => m.at).filter(Boolean);
      assert.deepEqual(ats, [...ats].sort().reverse());
      const identity = w.json(["recall", "--seat", "gahan", "--kind", "identity"]);
      assert.equal(identity.length, 1, "an identity is rewritten, not stacked");
      assert.equal(identity[0].text, "I am Gahan, generalist.");
      const cn = w.json(["recall", "--seat", "gahan", "--kind", "close-note"])[0];
      assert.equal(cn.bead, "ynw-1");
      assert.equal(cn.text, "Surprised: a.\nSharp edges: b.");
      const kudos = w.json(["recall", "--seat", "gahan", "--kind", "kudos"])[0];
      assert.equal(kudos.by, "marr");
      const note = w.json(["recall", "--human", "stakker"])[0];
      assert.deepEqual([note.kind, note.by, note.text], ["note", "marr", "FYI: merged."]);
      const facts = w.json(["recall", "--shared"]);
      assert.deepEqual(facts.map((m) => [m.kind, m.text]), [["fact", "Dolt ports clash."]]);
      const events = w.json(["recall", "--shared", "--kind", "event"]);
      assert.deepEqual(events.map((m) => [m.kind, m.bead, m.text]), [["event", "ynw-1", "ynw-1: closed; the Linux build was skipped."]]);
      assert.equal(w.json(["recall", "--shared", "--kind", "fact"]).length, 1, "events are not facts");
    } finally {
      w.done();
    }
  });

  test(`${memory}: recall honours --limit and keeps other seats out`, () => {
    const w = wheelhouse(memory);
    try {
      for (const t of ["one", "two", "three"])
        w.json(["remember", "--actor", "marr", "--kind", "kudos", "--seat", "gahan", "--text", t]);
      w.json(["remember", "--actor", "marr", "--kind", "kudos", "--seat", "hynde", "--text", "other"]);
      assert.equal(w.json(["recall", "--seat", "gahan", "--kind", "kudos", "--limit", "2"]).length, 2);
      assert.ok(w.json(["recall", "--seat", "gahan"]).every((m) => m.text !== "other"));
      assert.deepEqual(w.json(["recall", "--seat", "nobody"]), []);
    } finally {
      w.done();
    }
  });

  test(`${memory}: forget retires a memory by the id recall gave`, () => {
    const w = wheelhouse(memory);
    try {
      story(w);
      const h = w.json(["recall", "--seat", "gahan", "--kind", "handoff"])[0];
      assert.equal(w.run(["forget", "--id", h.id, "--reason", "picked up"]).status, 0);
      assert.deepEqual(w.json(["recall", "--seat", "gahan", "--kind", "handoff"]), []);
      assert.equal(w.run(["forget", "--id", h.id]).status, 1, "a reason is required");
    } finally {
      w.done();
    }
  });

  test(`${memory}: a failing store is an error, never an empty answer`, () => {
    const w = wheelhouse(memory);
    try {
      const r = w.run(["recall", "--seat", "gahan"], { STUB_FAIL: memory === "beads" ? "bd" : "ynm" });
      assert.equal(r.status, 3);
      assert.equal(r.stdout, "");
      assert.match(r.stderr, /failed/);
      const rem = w.run(["remember", "--actor", "a", "--kind", "birth", "--seat", "a", "--text", "x"], { STUB_FAIL: memory === "beads" ? "bd" : "ynm" });
      assert.equal(rem.status, 3);
    } finally {
      w.done();
    }
  });

  test(`${memory}: refuses a kind with the wrong scope or no bead`, () => {
    const w = wheelhouse(memory);
    try {
      const base = ["remember", "--actor", "gahan", "--text", "x"];
      assert.equal(w.run([...base, "--kind", "handoff"]).status, 1, "handoff needs --seat");
      assert.equal(w.run([...base, "--kind", "note", "--seat", "gahan"]).status, 1, "note needs --human");
      assert.equal(w.run([...base, "--kind", "close-note", "--seat", "gahan"]).status, 1, "close-note needs --bead");
      assert.equal(w.run([...base, "--kind", "fact", "--seat", "gahan"]).status, 1, "fact is shared");
      assert.equal(w.run([...base, "--kind", "event", "--shared"]).status, 1, "event needs --bead");
      assert.equal(w.run([...base, "--kind", "event", "--bead", "ynw-1", "--seat", "gahan"]).status, 1, "event is shared");
      assert.equal(w.run([...base, "--kind", "gossip", "--seat", "gahan"]).status, 1, "unknown kind");
      assert.equal(w.run([...base, "--kind", "kudos", "--seat", "Bad/Name"]).status, 1, "a seat is a command name");
      assert.equal(w.run(["recall", "--kind", "kudos"]).status, 1, "recall needs a scope");
    } finally {
      w.done();
    }
  });
}

test("ynm: runs today's ynm commands (namespace, subject, tags, pin on identity)", () => {
  const w = wheelhouse(null);
  try {
    w.json(["remember", "--actor", "gahan", "--kind", "identity", "--seat", "gahan", "--text", "I am Gahan."]);
    w.json(["remember", "--actor", "gahan", "--kind", "handoff", "--seat", "gahan", "--text", "notes"]);
    w.json(["remember", "--actor", "marr", "--kind", "note", "--human", "stakker", "--text", "hi"]);
    const c = w.calls();
    assert.match(c, /ynm remember --type semantic --level distributed --subject seat:gahan --tags identity .*--namespace seat\/gahan --content I am Gahan\./);
    assert.match(c, /ynm pin M1/);
    assert.match(c, /--type episodic --level distributed --subject seat:gahan --tags handoff/);
    assert.match(c, /--subject human:stakker --tags inbox .*--namespace human\/stakker --content From marr: hi/);
    assert.doesNotMatch(c, /^bd /m);
  } finally {
    w.done();
  }
});

test("ynm: a close note with subject seat:<c> never reports that subject as its bead", () => {
  const w = wheelhouse("ynm");
  try {
    const note = (id, subject, tags, data = {}) => ({ memoryId: id, namespace: "seat/gahan", tags, subject, content: "c " + id, level: "distributed", data, updatedAt: "2026-11-01T00:00:0" + id.slice(1) + "Z" });
    writeFileSync(join(w.dir, "stub", "ynm.json"), JSON.stringify([
      note("M1", "seat:gahan", ["close-note", "ynw-wckn"]),
      note("M2", "seat:gahan", ["close-note"]),
      note("M3", "ynw-abc1", ["close-note"]),
      note("M4", "seat:gahan", ["close-note", "ynw-zzz"], { bead: "ynw-data" }),
    ]));
    const beads = Object.fromEntries(w.json(["recall", "--seat", "gahan", "--kind", "close-note"]).map((m) => [m.id, m.bead]));
    assert.deepEqual(beads, { M1: "ynw-wckn", M2: null, M3: "ynw-abc1", M4: "ynw-data" });
  } finally {
    w.done();
  }
});

test("ynm: a second identity supersedes the first and is pinned", () => {
  const w = wheelhouse("ynm");
  try {
    story(w);
    assert.match(w.calls(), /ynm supersede --memory-id M1 /);
    assert.match(w.calls(), /ynm pin M\d+/);
  } finally {
    w.done();
  }
});

test("beads: keys follow the layout and never touch ynm", () => {
  const w = wheelhouse("beads");
  try {
    story(w);
    const keys = Object.keys(JSON.parse(readFileSync(join(w.dir, "stub", "bd.json"), "utf8"))).sort();
    assert.equal(keys.length, 7);
    assert.ok(keys.includes("seat/gahan/identity"));
    assert.ok(keys.includes("seat/gahan/handoff"));
    assert.ok(keys.includes("wheelhouse/dolt-ports"));
    assert.ok(keys.some((k) => /^event\/\d{8}T\d{6}Z-ynw-1$/.test(k)));
    assert.ok(keys.some((k) => /^seat\/gahan\/kudos\/\d{8}T\d{6}Z-marr$/.test(k)));
    assert.ok(keys.some((k) => /^seat\/gahan\/close-note\/\d{8}T\d{6}Z-ynw-1$/.test(k)));
    assert.ok(keys.some((k) => /^human\/stakker\/note\/\d{8}T\d{6}Z-marr$/.test(k)));
    assert.doesNotMatch(w.calls(), /^ynm /m);
  } finally {
    w.done();
  }
});

test("beads: text that starts with a dash is stored, and a bad wheelhouse.json is refused", () => {
  const w = wheelhouse("beads");
  try {
    w.json(["remember", "--actor", "a", "--kind", "birth", "--seat", "a", "--text", "--odd"]);
    assert.equal(w.json(["recall", "--seat", "a"])[0].text, "--odd");
    writeFileSync(join(w.dir, "wheelhouse.json"), JSON.stringify({ memory: "sqlite" }));
    assert.equal(w.run(["backend"]).status, 2);
    writeFileSync(join(w.dir, "wheelhouse.json"), "not json");
    assert.equal(w.run(["backend"]).status, 2);
  } finally {
    w.done();
  }
});

test("sync: beads reports memory and work with one result, and skips both without a Dolt remote", () => {
  const w = wheelhouse("beads");
  try {
    assert.deepEqual(w.json(["sync"]), { backend: "beads", memory: "skipped", work: "skipped" });
    assert.deepEqual(w.json(["sync"], { STUB_REMOTE: "1" }), { backend: "beads", memory: "synced", work: "synced" });
    assert.deepEqual(w.json(["sync", "--end"], { STUB_REMOTE: "1" }), { backend: "beads", memory: "pushed", work: "pushed" });
    assert.deepEqual(w.json(["sync"], { STUB_REMOTE: "1", STUB_SYNC_FAIL: "1" }), { backend: "beads", memory: "failed", work: "failed" });
  } finally {
    w.done();
  }
});

test("sync: ynm syncs memory when there is a git remote and leaves work alone", () => {
  const none = wheelhouse(null);
  const some = wheelhouse(null, { remote: true });
  try {
    assert.deepEqual(none.json(["sync"]), { backend: "ynm", memory: "skipped", work: "skipped" });
    assert.deepEqual(some.json(["sync"]), { backend: "ynm", memory: "synced", work: "skipped" });
    assert.deepEqual(some.json(["sync", "--end"]), { backend: "ynm", memory: "pushed", work: "skipped" });
  } finally {
    none.done();
    some.done();
  }
});

// ynm recall appends a memory's string data values to its content as a last line, so the stub
// above cannot show the bug: this case runs the real ynm in a scratch git repository with its own
// HOME (no personal or team store of the machine is touched). Skipped where ynm is not installed.
const realYnm = spawnSync("ynm", ["--version"], { encoding: "utf8" }).status === 0;
test("ynm (real): memories round-trip exactly and an inbox note parses", { skip: !realYnm && "ynm is not installed" }, () => {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-realynm-"));
  const env = { ...process.env, HOME: join(dir, "home") };
  const sh = (cmd, args) => spawnSync(cmd, args, { cwd: dir, env, encoding: "utf8" });
  try {
    mkdirSync(env.HOME);
    assert.equal(sh("git", ["init", "-q", "."]).status, 0);
    assert.equal(sh("git", ["-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "--allow-empty", "-m", "init"]).status, 0);
    const init = sh("ynm", ["init", "--json"]);
    assert.equal(init.status, 0, init.stderr);
    const mem = (args) => {
      const r = sh("bash", [script, ...args]);
      assert.equal(r.status, 0, r.stderr);
      return JSON.parse(r.stdout);
    };
    const closeNote = "Surprised: a.\nSharp edges: b.";
    mem(["remember", "--actor", "gahan", "--kind", "close-note", "--seat", "gahan", "--bead", "ynw-1", "--text", closeNote]);
    mem(["remember", "--actor", "marr", "--kind", "kudos", "--seat", "gahan", "--text", "Thanks."]);
    mem(["remember", "--actor", "marr", "--kind", "note", "--human", "stakker", "--text", "FYI: merged."]);
    mem(["remember", "--actor", "gahan", "--kind", "event", "--bead", "ynw-1", "--text", "ynw-1: closed."]);
    const cn = mem(["recall", "--seat", "gahan", "--kind", "close-note"])[0];
    assert.deepEqual([cn.text, cn.by, cn.bead], [closeNote, "gahan", "ynw-1"]);
    const kudos = mem(["recall", "--seat", "gahan", "--kind", "kudos"])[0];
    assert.deepEqual([kudos.text, kudos.by], ["Thanks.", "marr"]);
    const note = mem(["recall", "--human", "stakker"])[0];
    assert.deepEqual([note.kind, note.by, note.text], ["note", "marr", "FYI: merged."]);
    const ev = mem(["recall", "--shared", "--kind", "event"])[0];
    assert.deepEqual([ev.text, ev.bead], ["ynw-1: closed.", "ynw-1"]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
