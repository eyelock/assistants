// One live session per seat (assistants #179): wake.sh takes the seat's session bead, a second wake is
// refused with the holder named, --force takes the hold over and comments which session it replaced,
// --end (the handoff) releases it, and a crashed holder stays held until forced. The cases run the real
// wake.sh and session.sh from the layout ynh installs, against the real `bd` in a scratch graph
// (skipped when bd is not installed), with ynm stubbed. A session is told apart by WAKE_SESSION_TOKEN,
// or by CLAUDE_CODE_SESSION_ID, the variable Claude Code sets.
//
// CI has no bd, so the cases that need the real one are skipped there: CI runs only the case with a
// stubbed bd. These cases verify take, refuse, force and release only where bd is installed (run them
// locally before a change to session.sh or wake.sh).
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const hasBd = spawnSync("bd", ["--version"]).status === 0;
const roster = {
  seats: [
    { name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build." },
    { name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk with the human." },
  ],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};

function wheelhouse({ realBd = true } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-session-"));
  const bd = (...args) => spawnSync("bd", args, { cwd: dir, encoding: "utf8" });
  spawnSync("git", ["init", "-q", "-b", "main", "."], { cwd: dir });
  if (realBd) assert.equal(bd("init", "--skip-agents", "--prefix", "ss").status, 0);
  mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
  writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
  mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
  writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), "**Mandate:** Build one bead at a time.\n");
  // The layout ynh installs: the wake skill's scripts beside the work-graph skill's.
  for (const [skill, files] of [
    ["wake", ["wake.sh", "session.sh", "sync.sh", "render-wake.jq"]],
    ["work-graph", ["memory.sh", "wheelhouse-lib.sh"]],
  ]) {
    mkdirSync(join(dir, "plugin", "skills", skill, "scripts"), { recursive: true });
    for (const f of files) {
      try {
        copyFileSync(join(plugin, "skills", skill, "scripts", f), join(dir, "plugin", "skills", skill, "scripts", f));
      } catch {
        // sync.sh and render-wake.jq exist only once the wake split lands: the script reads without them.
      }
    }
  }
  mkdirSync(join(dir, "bin"));
  writeFileSync(join(dir, "bin", "ynm"), "#!/bin/sh\necho '[]'\n");
  chmodSync(join(dir, "bin", "ynm"), 0o755);
  return { dir, bd };
}

// One session of a seat, told apart from another by its token.
function run(dir, token, args, env = {}) {
  return spawnSync("bash", [join(dir, "plugin", "skills", "wake", "scripts", "wake.sh"), "--seat", "hynde", "--no-sync", ...args], {
    cwd: dir,
    encoding: "utf8",
    env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "", CLAUDE_CODE_SESSION_ID: "", TMPDIR: dir, WAKE_SESSION_TOKEN: token, ...env },
  });
}
const wake = (dir, token, extra = []) => run(dir, token, ["--format", "json", ...extra]);
const end = (dir, token) => run(dir, token, ["--end"]);
const sessionBead = ({ bd }) => JSON.parse(bd("list", "--label", "session:hynde", "--all", "--json").stdout)[0];

test("a first wake takes the seat's session bead, and the bead is not work", { skip: !hasBd }, () => {
  const w = wheelhouse();
  try {
    const r = wake(w.dir, "aaa");
    assert.equal(r.status, 0, r.stderr);
    const out = JSON.parse(r.stdout);
    assert.equal(out.session.state, "held");
    const bead = sessionBead(w);
    assert.equal(bead.status, "in_progress");
    assert.equal(bead.assignee, "hynde");
    assert.equal(JSON.parse(bead.notes).token, "aaa");
    assert.deepEqual(out.inProgress, [], "the hold is not the seat's work in progress");
    // Released, the bead is open and unassigned, and still not offered as work.
    assert.equal(JSON.parse(end(w.dir, "aaa").stdout).session, "released");
    assert.deepEqual(JSON.parse(wake(w.dir, "aaa").stdout).unassignedReady, []);
  } finally {
    rmSync(w.dir, { recursive: true, force: true });
  }
});

test("a second wake is refused, names the holder and when it started, and changes nothing", { skip: !hasBd }, () => {
  const w = wheelhouse();
  try {
    assert.equal(wake(w.dir, "aaa").status, 0);
    const before = sessionBead(w);
    const json = wake(w.dir, "bbb");
    assert.equal(json.status, 4, json.stderr);
    const refused = JSON.parse(json.stdout);
    assert.equal(refused.refused, true);
    assert.match(refused.session.holder.label, /session aaa/);
    assert.equal(refused.session.holder.started, JSON.parse(before.notes).started);
    const text = run(w.dir, "bbb", ["--format", "text"]);
    assert.equal(text.status, 4);
    assert.match(text.stdout, /# Not waking: hynde is already live/);
    assert.match(text.stdout, /session aaa, started \d{4}-\d\d-\d\dT/);
    assert.match(text.stdout, /do not run wake\.sh --force yourself/);
    assert.deepEqual(sessionBead(w).notes, before.notes, "the holder is still the first session");
    assert.doesNotMatch(text.stdout, /Who you are/, "a refused wake reads nothing else");
  } finally {
    rmSync(w.dir, { recursive: true, force: true });
  }
});

test("a forced wake takes the hold over and comments which session it replaced", { skip: !hasBd }, () => {
  const w = wheelhouse();
  try {
    assert.equal(wake(w.dir, "aaa").status, 0);
    const r = wake(w.dir, "bbb", ["--force"]);
    assert.equal(r.status, 0, r.stderr);
    const out = JSON.parse(r.stdout);
    assert.equal(out.session.state, "forced");
    assert.match(out.session.replaced.label, /session aaa/);
    const bead = sessionBead(w);
    assert.equal(JSON.parse(bead.notes).token, "bbb");
    assert.equal(bead.status, "in_progress");
    const comments = w.bd("comments", bead.id).stdout.replace(/\s+/g, " ");
    assert.match(comments, /Forced start/);
    assert.match(comments, /session bbb took over this hold from hynde session aaa/);
    const text = run(w.dir, "ccc", ["--format", "text", "--force"]);
    assert.match(text.stdout, /\*\*Forced start:\*\* you took this seat over from hynde session bbb/);
  } finally {
    rmSync(w.dir, { recursive: true, force: true });
  }
});

test("a handoff releases the hold, so the next start is not refused; only the holder releases it", { skip: !hasBd }, () => {
  const w = wheelhouse();
  try {
    assert.equal(wake(w.dir, "aaa").status, 0);
    // A refused session's own session-end hook runs --end too: it must leave the live session's hold alone.
    assert.equal(JSON.parse(end(w.dir, "bbb").stdout).session, "not-yours");
    assert.equal(sessionBead(w).status, "in_progress");
    assert.equal(JSON.parse(end(w.dir, "aaa").stdout).session, "released");
    const bead = sessionBead(w);
    assert.equal(bead.status, "open");
    assert.equal(bead.assignee, undefined);
    assert.equal(wake(w.dir, "bbb").status, 0, "the seat can start again");
    assert.equal(JSON.parse(end(w.dir, "aaa").stdout).session, "not-yours", "the old session no longer holds it");
  } finally {
    rmSync(w.dir, { recursive: true, force: true });
  }
});

test("a crashed holder stays held, with no lease to lapse and nothing to reclaim, until a start is forced", { skip: !hasBd }, () => {
  const w = wheelhouse();
  try {
    assert.equal(wake(w.dir, "aaa").status, 0);
    // The holder crashes: no --end. The hold is a plain claim, so no lease lapses for bd's reclaim to free.
    assert.doesNotMatch(w.bd("show", sessionBead(w).id).stdout, /Lease:/);
    assert.equal(wake(w.dir, "bbb").status, 4, "still held");
    assert.equal(wake(w.dir, "bbb").status, 4, "and still");
    assert.equal(wake(w.dir, "bbb", ["--force"]).status, 0, "until a start is forced");
    assert.equal(wake(w.dir, "ccc").status, 4, "and then the forcing session holds it");
  } finally {
    rmSync(w.dir, { recursive: true, force: true });
  }
});

test("a bd that cannot be read never stops a wake: the block says the check was not made", () => {
  const w = wheelhouse({ realBd: false });
  try {
    writeFileSync(join(w.dir, "bin", "bd"), "#!/bin/sh\nexit 1\n");
    chmodSync(join(w.dir, "bin", "bd"), 0o755);
    const r = run(w.dir, "aaa", ["--format", "text"]);
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /\*\*Live-session check not made:\*\*/);
  } finally {
    rmSync(w.dir, { recursive: true, force: true });
  }
});

test("the token comes from CLAUDE_CODE_SESSION_ID, so a refused session's end leaves the live hold alone", { skip: !hasBd }, () => {
  const w = wheelhouse();
  try {
    const as = (id) => ({ CLAUDE_CODE_SESSION_ID: id });
    assert.equal(run(w.dir, "", ["--format", "json"], as("live-session")).status, 0);
    assert.equal(run(w.dir, "", ["--format", "json"], as("second-session")).status, 4);
    assert.equal(JSON.parse(run(w.dir, "", ["--end"], as("second-session")).stdout).session, "not-yours");
    assert.equal(sessionBead(w).status, "in_progress", "the live session still holds it");
    assert.doesNotMatch(sessionBead(w).notes, /live-session/, "the id itself is never written");
    assert.equal(JSON.parse(run(w.dir, "", ["--end"], as("live-session")).stdout).session, "released");
  } finally {
    rmSync(w.dir, { recursive: true, force: true });
  }
});

test("with no session id at all, a refused session's end releases nothing, and the live one's end still does", { skip: !hasBd }, () => {
  const w = wheelhouse();
  try {
    assert.equal(wake(w.dir, "").status, 0);
    assert.equal(wake(w.dir, "").status, 4, "the second start is refused");
    assert.equal(JSON.parse(end(w.dir, "").stdout).session, "not-yours", "its own end releases nothing");
    assert.equal(sessionBead(w).status, "in_progress");
    assert.equal(JSON.parse(end(w.dir, "").stdout).session, "released", "the live session's end does");
    assert.equal(sessionBead(w).status, "open");
  } finally {
    rmSync(w.dir, { recursive: true, force: true });
  }
});
