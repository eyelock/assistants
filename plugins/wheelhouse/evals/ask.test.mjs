// ask.sh, the seat-to-seat ask: open (each kind), answer, return and show, run against a small
// Wheelhouse with a stateful bd stand-in (files/ask-bd-stub.sh, beads kept in a JSON file).
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const askSh = join(here, "..", "skills", "work-graph", "scripts", "ask.sh");
const bdStub = join(here, "files", "ask-bd-stub.sh");

const roster = {
  seats: [
    { name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk with the human." },
    { name: "Dalglish", group: "workers", command: "dalglish", harness: "harnesses/dalglish", mandate: "Build." },
    { name: "Gore", group: "crew", command: "gore", harness: "harnesses/gore", mandate: "Review." },
  ],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};

const seed = (id, over = {}) => ({
  id,
  title: `bead ${id}`,
  description: "",
  status: "open",
  priority: 2,
  created_by: "gore",
  assignee: "",
  labels: [],
  created_at: "2026-11-10T12:00:00Z",
  comments: [],
  ...over,
});

// A Wheelhouse in a temp folder with the bd stand-in on PATH; beads seeds the store.
function world(beads = []) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-ask-"));
  mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
  writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
  mkdirSync(join(dir, "bin"));
  copyFileSync(bdStub, join(dir, "bin", "bd"));
  chmodSync(join(dir, "bin", "bd"), 0o755);
  const store = join(dir, "store.json");
  writeFileSync(store, JSON.stringify({ beads, edges: [] }));
  const env = {
    ...process.env,
    PATH: `${join(dir, "bin")}:${process.env.PATH}`,
    BD_STORE: store,
    BD_LOG: join(dir, "bd.log"),
    BD_NOW: "2026-11-10T12:00:00Z",
    BEADS_ACTOR: "",
  };
  const ask = (args, extra = {}) =>
    spawnSync("bash", [askSh, ...args], { cwd: dir, encoding: "utf8", env: { ...env, ...extra } });
  const state = () => JSON.parse(readFileSync(store, "utf8"));
  const bead = (id) => state().beads.find((b) => b.id === id);
  return { dir, ask, state, bead, log: () => readFileSync(join(dir, "bd.log"), "utf8"), done: () => rmSync(dir, { recursive: true, force: true }) };
}

const json = (r) => {
  assert.equal(r.status, 0, r.stderr);
  return JSON.parse(r.stdout);
};

test("open a question: assigned to the answering seat, as the asker, blocking the asker's bead", () => {
  const w = world([seed("hq-1", { labels: ["repo:assistants"], assignee: "dalglish", status: "in_progress" })]);
  try {
    const out = json(
      w.ask(["open", "--to", "gore", "--kind", "question", "--title", "Is the rule right?", "--from", "dalglish", "--blocks", "hq-1"]),
    );
    assert.equal(out.to, "gore");
    assert.equal(out.askedBy, "dalglish");
    assert.equal(out.kind, "question");
    assert.equal(out.blocks, "hq-1");
    assert.equal(out.repo, "assistants");
    assert.equal(out.session, "hq-gore");
    assert.match(out.nudge, /hq-gore/);
    const b = w.bead(out.id);
    assert.equal(b.created_by, "dalglish");
    assert.equal(b.assignee, "gore");
    assert.deepEqual(b.labels.sort(), ["ask", "ask:question", "repo:assistants"]);
    assert.deepEqual(w.state().edges, [{ from: out.id, to: "hq-1" }]);
  } finally {
    w.done();
  }
});

test("open a request to the desk by its alias: the desk's session address is the Wheelhouse's name", () => {
  const w = world();
  try {
    const out = json(w.ask(["open", "--to", "desk", "--kind", "request", "--title", "Wake May", "--from", "dalglish", "--repo", "ynw"]));
    assert.equal(out.to, "hq");
    assert.equal(out.session, "hq");
    assert.equal(out.repo, "ynw");
    assert.deepEqual(w.bead(out.id).labels.sort(), ["ask", "ask:request", "repo:ynw"]);
    assert.equal(w.bead(out.id).assignee, "hq");
  } finally {
    w.done();
  }
});

test("open a report blocking nothing: it goes to the desk by default, and takes no --blocks or other seat", () => {
  const w = world([seed("hq-1")]);
  try {
    const out = json(w.ask(["open", "--kind", "report", "--title", "PR 12 merged", "--from", "gore"]));
    assert.equal(out.to, "hq");
    assert.equal(out.blocks, null);
    assert.deepEqual(w.bead(out.id).labels.sort(), ["ask", "ask:report"]);
    assert.deepEqual(w.state().edges, []);
    const blocking = w.ask(["open", "--kind", "report", "--title", "x", "--from", "gore", "--blocks", "hq-1"]);
    assert.equal(blocking.status, 1);
    assert.match(blocking.stderr, /blocks nothing/);
    const other = w.ask(["open", "--to", "dalglish", "--kind", "report", "--title", "x", "--from", "gore"]);
    assert.equal(other.status, 1);
    assert.match(other.stderr, /goes to the desk/);
  } finally {
    w.done();
  }
});

test("open refuses what is not an ask: no --to for a question, a human, itself, an unknown seat, a bad kind", () => {
  const w = world();
  try {
    const refused = (args, pattern) => {
      const r = w.ask(args);
      assert.equal(r.status, 1, `${args.join(" ")}: ${r.stderr}`);
      assert.match(r.stderr, pattern);
    };
    refused(["open", "--kind", "question", "--title", "t", "--from", "gore"], /needs --to/);
    refused(["open", "--to", "rook", "--kind", "question", "--title", "t", "--from", "gore"], /human/);
    refused(["open", "--to", "gore", "--kind", "question", "--title", "t", "--from", "gore"], /yourself/);
    refused(["open", "--to", "nobody", "--kind", "question", "--title", "t", "--from", "gore"], /not a seat/);
    refused(["open", "--to", "gore", "--kind", "return", "--title", "t", "--from", "dalglish"], /--kind question, request or report/);
    refused(["open", "--to", "gore", "--kind", "question", "--title", "t", "--from", "stranger"], /not a seat/);
    refused(["open", "--to", "gore", "--kind", "question", "--title", "t"], /--from/);
    refused(["open", "--to", "gore", "--kind", "question", "--from", "dalglish"], /--title/);
    assert.deepEqual(w.state().beads, []);
  } finally {
    w.done();
  }
});

test("a seat on trial (a harness on the branch, no roster entry) may ask and be asked", () => {
  const w = world();
  try {
    mkdirSync(join(w.dir, "harnesses", "mccoist"), { recursive: true });
    writeFileSync(join(w.dir, "harnesses", "mccoist", "AGENTS.md"), "**Mandate:** Build.\n");
    const out = json(w.ask(["open", "--to", "mccoist", "--kind", "request", "--title", "t", "--from", "gore"]));
    assert.equal(out.session, "hq-mccoist");
    json(w.ask(["open", "--to", "gore", "--kind", "question", "--title", "t", "--from", "mccoist"]));
  } finally {
    w.done();
  }
});

test("answer comments the answer and re-assigns the ask to its asker; the asker then closes it", () => {
  const w = world();
  try {
    const opened = json(w.ask(["open", "--to", "gore", "--kind", "question", "--title", "Which?", "--from", "dalglish"]));
    const out = json(w.ask(["answer", opened.id, "--text", "The first.", "--from", "gore"]));
    assert.deepEqual(out, { id: opened.id, answeredBy: "gore", to: "dalglish" });
    const b = w.bead(opened.id);
    assert.equal(b.assignee, "dalglish");
    assert.deepEqual(b.comments, ["The first."]);
    assert.equal(b.status, "open");
    // Answered once: the same seat can't answer it again, it is the asker's now.
    const again = w.ask(["answer", opened.id, "--text", "Again.", "--from", "gore"]);
    assert.equal(again.status, 1);
    assert.match(again.stderr, /only the seat an ask is assigned to/);
  } finally {
    w.done();
  }
});

test("answer refuses a non-ask, a report, a return, a closed ask and a seat it isn't assigned to", () => {
  const w = world([
    seed("hq-1", { assignee: "gore" }),
    seed("hq-2", { assignee: "hq", labels: ["ask", "ask:report"], created_by: "gore" }),
    seed("hq-3", { assignee: "hq", labels: ["ask", "ask:return"], created_by: "gore" }),
    seed("hq-4", { assignee: "gore", status: "closed", labels: ["ask", "ask:question"], created_by: "dalglish" }),
    seed("hq-5", { assignee: "gore", labels: ["ask", "ask:question"], created_by: "dalglish" }),
  ]);
  try {
    const refused = (id, from, pattern) => {
      const r = w.ask(["answer", id, "--text", "x", "--from", from]);
      assert.equal(r.status, 1, `${id}: ${r.stderr}`);
      assert.match(r.stderr, pattern);
    };
    refused("hq-1", "gore", /not an ask/);
    refused("hq-2", "hq", /report/);
    refused("hq-3", "hq", /returned bead/);
    refused("hq-4", "gore", /already closed/);
    refused("hq-5", "dalglish", /not to dalglish/);
    refused("hq-9", "gore", /no bead/);
    assert.equal(w.ask(["answer", "hq-5", "--from", "gore"]).status, 1);
    assert.equal(w.bead("hq-5").assignee, "gore");
    assert.deepEqual(w.bead("hq-5").comments, []);
  } finally {
    w.done();
  }
});

test("return comments why, releases the claim and re-assigns the same bead to the desk: no new bead", () => {
  const w = world([seed("hq-1", { assignee: "dalglish", status: "in_progress", labels: ["repo:ynh"] })]);
  try {
    const out = json(w.ask(["return", "hq-1", "--reason", "outside my charter", "--from", "dalglish"]));
    assert.deepEqual(out, { id: "hq-1", returnedBy: "dalglish", to: "hq" });
    const st = w.state();
    assert.equal(st.beads.length, 1);
    const b = w.bead("hq-1");
    assert.equal(b.assignee, "hq");
    assert.equal(b.status, "open");
    assert.deepEqual(b.labels.sort(), ["ask", "ask:return", "repo:ynh"]);
    assert.match(b.comments[0], /outside my charter/);
    assert.doesNotMatch(w.log(), /^bd create/m);
  } finally {
    w.done();
  }
});

test("return refuses a bead the seat doesn't hold, a report, a closed bead, the desk, and a missing reason", () => {
  const w = world([
    seed("hq-1", { assignee: "gore", status: "in_progress" }),
    seed("hq-2", { assignee: "dalglish", labels: ["ask", "ask:report"] }),
    seed("hq-3", { assignee: "dalglish", status: "closed" }),
  ]);
  try {
    const refused = (args, pattern) => {
      const r = w.ask(["return", ...args]);
      assert.equal(r.status, 1, `${args.join(" ")}: ${r.stderr}`);
      assert.match(r.stderr, pattern);
    };
    refused(["hq-1", "--reason", "x", "--from", "dalglish"], /not to dalglish/);
    refused(["hq-2", "--reason", "x", "--from", "dalglish"], /report/);
    refused(["hq-3", "--reason", "x", "--from", "dalglish"], /already closed/);
    refused(["hq-1", "--reason", "x", "--from", "hq"], /the desk/);
    refused(["hq-1", "--from", "gore"], /--reason/);
    assert.equal(w.bead("hq-1").assignee, "gore");
  } finally {
    w.done();
  }
});

// Four asks of different ages and kinds, for show.
const NOW = String(Date.parse("2026-11-10T12:00:00Z") / 1000);
function showWorld() {
  return world([
    seed("hq-1", { labels: ["ask", "ask:question"], assignee: "gore", created_by: "dalglish", created_at: "2026-11-08T12:00:00Z" }),
    seed("hq-2", { labels: ["ask", "ask:request"], assignee: "gore", created_by: "dalglish", created_at: "2026-11-10T11:30:00Z" }),
    seed("hq-3", { labels: ["ask", "ask:question"], assignee: "dalglish", created_by: "dalglish", created_at: "2026-11-09T12:00:00Z" }),
    seed("hq-4", { labels: ["ask", "ask:report"], assignee: "hq", created_by: "gore", created_at: "2026-11-08T00:00:00Z" }),
    seed("hq-5", { labels: ["ask", "ask:question"], assignee: "gore", created_by: "dalglish", status: "closed" }),
    seed("hq-6", { labels: [], assignee: "gore" }),
  ]);
}

test("show lists a seat's open asks, oldest first, with age, kind, asker and what each blocks", () => {
  const w = showWorld();
  try {
    const st = w.state();
    st.edges.push({ from: "hq-1", to: "hq-9" });
    writeFileSync(join(w.dir, "store.json"), JSON.stringify(st));
    const out = json(w.ask(["show", "--seat", "gore"], { ASK_NOW: NOW }));
    assert.equal(out.seat, "gore");
    assert.equal(out.all, false);
    assert.equal(out.count, 2);
    assert.deepEqual(
      out.asks.map((a) => [a.id, a.kind, a.askedBy, a.age, a.ageSeconds, a.blocks]),
      [
        ["hq-1", "question", "dalglish", "2d", 172800, ["hq-9"]],
        ["hq-2", "request", "dalglish", "30m", 1800, []],
      ],
    );
    assert.deepEqual(out.errors, []);
  } finally {
    w.done();
  }
});

test("show defaults to $BEADS_ACTOR, marks an answered ask for its asker, and --all lists every seat's", () => {
  const w = showWorld();
  try {
    const mine = json(w.ask(["show"], { BEADS_ACTOR: "dalglish", ASK_NOW: NOW }));
    assert.deepEqual(
      mine.asks.map((a) => [a.id, a.answered]),
      [["hq-3", true]],
    );
    const all = json(w.ask(["show", "--all"], { ASK_NOW: NOW }));
    assert.equal(all.seat, null);
    assert.equal(all.all, true);
    assert.deepEqual(
      all.asks.map((a) => a.id),
      ["hq-4", "hq-1", "hq-3", "hq-2"],
    );
    const report = all.asks.find((a) => a.id === "hq-4");
    assert.equal(report.kind, "report");
    assert.equal(report.assignee, "hq");
  } finally {
    w.done();
  }
});

test("show --older-than keeps only the asks at least that old", () => {
  const w = showWorld();
  try {
    const day = json(w.ask(["show", "--all", "--older-than", "24h"], { ASK_NOW: NOW }));
    assert.equal(day.olderThanSeconds, 86400);
    assert.deepEqual(
      day.asks.map((a) => a.id),
      ["hq-4", "hq-1", "hq-3"],
    );
    const minutes = json(w.ask(["show", "--all", "--older-than", "20m"], { ASK_NOW: NOW }));
    assert.equal(minutes.count, 4);
    const none = json(w.ask(["show", "--all", "--older-than", "9d"], { ASK_NOW: NOW }));
    assert.deepEqual(none.asks, []);
    assert.equal(w.ask(["show", "--all", "--older-than", "soon"]).status, 1);
  } finally {
    w.done();
  }
});

test("show with nothing open is an empty list, not an error; with bd failing it exits 3 and says so", () => {
  const w = world();
  try {
    const out = json(w.ask(["show", "--seat", "gore"]));
    assert.deepEqual([out.count, out.asks, out.errors], [0, [], []]);
    writeFileSync(join(w.dir, "bin", "bd"), "#!/bin/sh\necho 'dolt is down' >&2\nexit 1\n");
    const broken = w.ask(["show", "--seat", "gore"]);
    assert.equal(broken.status, 3);
    assert.match(broken.stderr, /bd list failed/);
    const printed = JSON.parse(broken.stdout);
    assert.equal(printed.errors.length, 1);
    assert.equal(printed.count, 0);
  } finally {
    w.done();
  }
});

test("every bd call is bounded, and a bd that hangs fails the call rather than the seat", () => {
  const w = world();
  try {
    writeFileSync(join(w.dir, "bin", "bd"), "#!/bin/sh\nexec sleep 30\n");
    const started = Date.now();
    const r = w.ask(["show", "--seat", "gore"], { ASK_BD_TIMEOUT: "1" });
    assert.equal(r.status, 3);
    assert.ok(Date.now() - started < 10000, "show waited on a hung bd");
  } finally {
    w.done();
  }
});

test("not a Wheelhouse is exit 2; no command, an unknown command and --help are handled", () => {
  const w = world();
  try {
    const empty = mkdtempSync(join(tmpdir(), "wheelhouse-ask-empty-"));
    try {
      const r = spawnSync("bash", [askSh, "show", "--dir", empty, "--all"], { encoding: "utf8" });
      assert.equal(r.status, 2);
    } finally {
      rmSync(empty, { recursive: true, force: true });
    }
    assert.equal(w.ask([]).status, 1);
    assert.equal(w.ask(["nope"]).status, 1);
    const help = w.ask(["--help"]);
    assert.equal(help.status, 0);
    assert.match(help.stdout, /ask\.sh open/);
  } finally {
    w.done();
  }
});
