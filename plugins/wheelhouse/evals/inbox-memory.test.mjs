// inbox.sh note and show go through memory.sh, so a human's notes live in whichever memory the
// Wheelhouse keeps (wheelhouse.json: ynm, the default, or Beads). Each case runs the real inbox.sh
// in a scratch Wheelhouse with ynm and bd stubbed by small stateful node programs, on both
// backends: a note is written, shown with the id and the backend's own retire command, retired,
// and gone; and a failing backend is an error, never an empty inbox.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const inboxSh = join(plugin, "skills", "work-graph", "scripts", "inbox.sh");
const memorySh = join(plugin, "skills", "work-graph", "scripts", "memory.sh");

const roster = {
  seats: [
    { name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk with the human." },
    { name: "Gahan", group: "workers", command: "gahan", harness: "harnesses/gahan", mandate: "Build." },
  ],
  humans: [{ name: "Stakker", command: "stakker", pronouns: "they/them", default: true }],
};

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
} else if (a[0] === "ready") {
  console.log("[]");
} else if (a[0] === "dolt") {
  console.log(process.env.STUB_REMOTE ? '[{"name":"origin"}]' : "[]");
} else if (a[0] === "sync") {
  if (process.env.STUB_SYNC_FAIL) process.exit(1);
}
`;

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
  console.log(JSON.stringify(db.filter((m) => !m.tombstoned && (!ns || m.namespace === ns) && (!subj || m.subject === subj) &&
    (!tags || tags.split(",").every((t) => m.tags.includes(t)))).reverse()));
}
`;

function wheelhouse(memory) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-inbox-memory-"));
  mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
  writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
  mkdirSync(join(dir, "bin"));
  mkdirSync(join(dir, "stub"));
  for (const [name, body] of [["bd", bdStub], ["ynm", ynmStub]]) {
    writeFileSync(join(dir, "bin", name), body);
    chmodSync(join(dir, "bin", name), 0o755);
  }
  if (memory) writeFileSync(join(dir, "wheelhouse.json"), JSON.stringify({ tasks: "beads", memory }));
  const env = (extra) => ({
    ...process.env,
    PATH: `${join(dir, "bin")}:${process.env.PATH}`,
    STUB_DIR: join(dir, "stub"),
    GIT_CONFIG_GLOBAL: "/dev/null",
    ...extra,
  });
  const inbox = (args, extra = {}) => spawnSync("bash", [inboxSh, ...args], { cwd: dir, encoding: "utf8", env: env(extra) });
  const calls = () => {
    const r = spawnSync("cat", [join(dir, "stub", "calls.log")], { encoding: "utf8" });
    return r.stdout ?? "";
  };
  return { dir, inbox, calls };
}

for (const [backend, memory] of [["ynm", null], ["ynm", "ynm"], ["beads", "beads"]]) {
  const label = memory ? backend : "ynm (no wheelhouse.json)";

  test(`${label}: note is written, shown, retired and gone`, () => {
    const w = wheelhouse(memory);
    try {
      const note = w.inbox(["note", "--from", "gahan", "--to", "default", "--content", "PR 12 is ready: thanks"]);
      assert.equal(note.status, 0, note.stderr);
      const written = JSON.parse(note.stdout);
      assert.equal(written.to, "stakker");
      assert.equal(written.namespace, "human/stakker");
      assert.equal(written.backend, backend);
      assert.ok(written.memoryId);
      if (backend === "beads") assert.match(written.memoryId, /^human\/stakker\/note\/\d{8}T\d{6}Z-gahan$/);

      const show = w.inbox(["show"]);
      assert.equal(show.status, 0, show.stderr);
      const json = JSON.parse(show.stdout);
      assert.equal(json.empty, false);
      assert.equal(json.errors.length, 0);
      const notes = json.humans[0].notes;
      assert.equal(notes.length, 1);
      assert.equal(notes[0].memoryId, written.memoryId);
      assert.equal(notes[0].content, "From gahan: PR 12 is ready: thanks");
      assert.equal(notes[0].by, "gahan");
      assert.match(json.relay, /bash \S+\/memory\.sh forget --id <its memoryId> --reason relayed/);
      assert.doesNotMatch(json.relay, /ynm forget|bd forget/);

      const gone = spawnSync("bash", [memorySh, "forget", "--dir", w.dir, "--id", notes[0].memoryId, "--reason", "relayed"], {
        encoding: "utf8",
        env: { ...process.env, PATH: `${join(w.dir, "bin")}:${process.env.PATH}`, STUB_DIR: join(w.dir, "stub") },
      });
      assert.equal(gone.status, 0, gone.stderr);
      const after = JSON.parse(w.inbox(["show"]).stdout);
      assert.deepEqual(after.humans[0].notes, []);
      assert.equal(after.empty, true);
    } finally {
      rmSync(w.dir, { recursive: true, force: true });
    }
  });

  test(`${label}: a named human's notes are theirs alone`, () => {
    const w = wheelhouse(memory);
    try {
      assert.equal(w.inbox(["note", "--from", "gahan", "--to", "david", "--content", "for david"]).status, 0);
      assert.equal(w.inbox(["note", "--from", "gahan", "--to", "default", "--content", "for stakker"]).status, 0);
      const json = JSON.parse(w.inbox(["show", "--name", "David"]).stdout);
      assert.deepEqual(json.humans.map((h) => [h.command, h.notes.map((n) => n.content)]), [
        ["david", ["From gahan: for david"]],
        ["stakker", ["From gahan: for stakker"]],
      ]);
    } finally {
      rmSync(w.dir, { recursive: true, force: true });
    }
  });

  const tool = backend === "beads" ? "bd" : "ynm";
  test(`${label}: a failing memory is an error, never an empty inbox`, () => {
    const w = wheelhouse(memory);
    try {
      const show = w.inbox(["show"], { STUB_FAIL: tool });
      assert.equal(show.status, 3, show.stdout);
      const json = JSON.parse(show.stdout);
      assert.equal(json.empty, null);
      assert.equal(json.humans[0].notes, null);
      assert.match(json.errors.join("\n"), new RegExp(`${tool} (recall|memories) failed`));
      const note = w.inbox(["note", "--from", "gahan", "--content", "x"], { STUB_FAIL: tool });
      assert.equal(note.status, 3);
      assert.match(note.stderr, /memory\.sh remember failed/);
    } finally {
      rmSync(w.dir, { recursive: true, force: true });
    }
  });
}

test("an unknown memory in wheelhouse.json is an error, not an empty inbox", () => {
  const w = wheelhouse("sqlite");
  try {
    const show = w.inbox(["show"]);
    assert.equal(show.status, 3);
    assert.equal(JSON.parse(show.stdout).empty, null);
  } finally {
    rmSync(w.dir, { recursive: true, force: true });
  }
});
