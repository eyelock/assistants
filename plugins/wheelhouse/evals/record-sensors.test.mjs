// The record sensors (sensors/record/*.sh) and their runner (sensors/run-record-sensors.sh): each sensor
// counts one thing the Wheelhouse's record gets wrong, one output line per item, against a fixture work
// graph (a bd stub answering `bd list --status <s>` from a JSON file) and a stub gh (answering from a JSON
// file), with no ynh on the PATH. The runner keeps the counts and reports a count that rose; the patrol runs
// the runner; the desk's wake prints one line per sensor above zero.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const sensors = join(plugin, "sensors");
const R = "example/widget";
const pr = (n) => `https://github.com/${R}/pull/${n}`;

const PAST = new Date(Date.now() - 3600e3).toISOString();
const FUTURE = new Date(Date.now() + 3600e3).toISOString();

const bdStub = `#!/bin/sh
# bd list --status <s> --limit 0 --json: the beads of that status from $BD_STATE
[ "$1" = list ] || { echo "bd stub: unexpected $*" >&2; exit 1; }
[ -z "$BD_FAIL" ] || { echo "bd is busy" >&2; exit 1; }
while [ $# -gt 0 ]; do [ "$1" = --status ] && s="$2"; shift; done
jq -c --arg s "$s" '.[$s] // []' "$BD_STATE"
`;

const ghStub = `#!/bin/sh
[ -z "$GH_FAIL" ] || { echo "HTTP 502" >&2; exit 1; }
repo=""; prev=""
for a in "$@"; do [ "$prev" = -R ] && repo="$a"; prev="$a"; done
case "$1 $2" in
  "pr view") jq -r --arg u "$3" '.pulls[$u] // empty' "$GH_STATE" ;;
  "pr list") jq -c --arg r "$repo" '.prs[$r] // []' "$GH_STATE" ;;
  api*)
    case "$2" in
      repos/*/milestones*) r=\${2#repos/}; r=\${r%%/milestones*}; jq -c --arg r "$r" '.milestones[$r] // []' "$GH_STATE" ;;
      repos/*/tags*) r=\${2#repos/}; r=\${r%%/tags*}; jq -r --arg r "$r" '.tags[$r][]?' "$GH_STATE" ;;
      repos/*/issues/events*) r=\${2#repos/}; r=\${r%%/issues/events*}; jq -c --arg r "$r" '.events[$r] // []' "$GH_STATE" ;;
      *) echo "gh stub: unexpected $*" >&2; exit 1 ;;
    esac ;;
  *) echo "gh stub: unexpected $*" >&2; exit 1 ;;
esac
`;

// A Wheelhouse folder with the stubs on a PATH that has no ynh, and the plugin's sensors and skills as installed.
function world({ beads = {}, gh = {} } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-record-"));
  const bin = join(dir, "bin");
  mkdirSync(bin);
  const tools = {};
  for (const t of [
    "bash",
    "jq",
    "grep",
    "sed",
    "awk",
    "head",
    "tr",
    "cat",
    "date",
    "dirname",
    "basename",
    "mkdir",
    "mv",
    "rm",
    "perl",
    "env",
    "sort",
    "git",
  ]) {
    const found = spawnSync("/usr/bin/env", ["bash", "-c", `command -v ${t}`], {
      encoding: "utf8",
    }).stdout.trim();
    if (found) tools[t] = found;
  }
  for (const [t, p] of Object.entries(tools)) spawnSync("ln", ["-s", p, join(bin, t)]);
  writeFileSync(join(bin, "bd"), bdStub);
  writeFileSync(join(bin, "gh"), ghStub);
  chmodSync(join(bin, "bd"), 0o755);
  chmodSync(join(bin, "gh"), 0o755);
  const wh = join(dir, "wh");
  mkdirSync(wh);
  writeFileSync(join(wh, "AGENTS.md"), "# a Wheelhouse\n");
  writeFileSync(join(dir, "bd.json"), JSON.stringify(beads));
  writeFileSync(join(dir, "gh.json"), JSON.stringify(gh));
  const env = (extra = {}) => ({
    PATH: bin,
    HOME: dir,
    BD_STATE: join(dir, "bd.json"),
    GH_STATE: join(dir, "gh.json"),
    WHEELHOUSE_REPOS: R,
    ...extra,
  });
  const set = (file, data) => writeFileSync(join(dir, file), JSON.stringify(data));
  return { dir, wh, env, setBeads: (b) => set("bd.json", b), setGh: (g) => set("gh.json", g) };
}

function sensor(w, name, extra = {}) {
  const r = spawnSync("bash", [join(sensors, "record", `${name}.sh`)], {
    cwd: w.wh,
    encoding: "utf8",
    env: w.env(extra),
  });
  return { code: r.status, lines: r.stdout.split("\n").filter(Boolean), err: r.stderr };
}

const bead = (id, over = {}) => ({
  id,
  title: `Bead ${id}`,
  assignee: "gahan",
  labels: [],
  notes: "",
  ...over,
});

test("stale-claims counts an in-progress bead whose lease lapsed, and not a live claim, a session hold or a bead with an open pull request", () => {
  const w = world({
    beads: {
      in_progress: [
        bead("a-1", { lease_expires_at: PAST }),
        bead("a-2", { lease_expires_at: FUTURE }),
        bead("a-3", { lease_expires_at: PAST, labels: ["session:gahan"] }),
        bead("a-4", { lease_expires_at: PAST, notes: `PR: ${pr(4)}` }),
        bead("a-5", { lease_expires_at: PAST, notes: `PR: ${pr(5)}` }),
        bead("a-6", { assignee: "" }),
      ],
    },
    gh: { pulls: { [pr(4)]: "OPEN", [pr(5)]: "CLOSED" } },
  });
  const r = sensor(w, "stale-claims");
  assert.equal(r.code, 1, r.err);
  assert.deepEqual(
    r.lines.map((l) => l.split(":")[0]),
    ["a-1", "a-5", "a-6"],
  );
  assert.ok(r.lines.some((l) => l.startsWith("a-1:") && l.includes("held by gahan")));
  assert.ok(!r.lines.some((l) => /^a-(3|4):/.test(l)), r.lines.join("\n"));
});

test("stale-claims prints nothing and exits 0 when every claim is live, and exits 3 when bd fails", () => {
  const w = world({ beads: { in_progress: [bead("a-1", { lease_expires_at: FUTURE })] } });
  assert.deepEqual(sensor(w, "stale-claims"), { code: 0, lines: [], err: "" });
  const bad = sensor(w, "stale-claims", { BD_FAIL: "1" });
  assert.equal(bad.code, 3);
  assert.match(bad.err, /bd could not list/);
});

test("stale-claims names the lease once, or says there is none", () => {
  const w = world({
    beads: {
      in_progress: [bead("a-1", { lease_expires_at: PAST }), bead("a-2", { assignee: "" })],
    },
  });
  const r = sensor(w, "stale-claims");
  assert.deepEqual(r.lines, [
    `a-1: Bead a-1 (held by gahan, lease ended ${PAST})`,
    "a-2: Bead a-2 (held by no one, no lease at all)",
  ]);
});

test("stale-claims exits 3, and counts nothing, when gh can't say whether a waiting pull request is open", () => {
  const w = world({
    beads: {
      in_progress: [
        bead("a-1", { lease_expires_at: PAST, notes: `PR: ${pr(1)}` }),
        bead("a-2", { lease_expires_at: PAST }),
      ],
    },
    gh: { pulls: { [pr(1)]: "OPEN" } },
  });
  const failing = sensor(w, "stale-claims", { GH_FAIL: "1" });
  assert.equal(failing.code, 3);
  assert.deepEqual(
    failing.lines.filter((l) => l.startsWith("a-1")),
    [],
  );
  assert.match(failing.err, /could not read the state of .*pull\/1/);
  // gh missing altogether is the same: no gh on the PATH.
  rmSync(join(w.dir, "bin", "gh"));
  const missing = sensor(w, "stale-claims");
  assert.equal(missing.code, 3);
  assert.match(missing.err, /could not read the state/);
  // and with gh answering, the open pull request is skipped and the other bead counted.
  const ok = world({
    beads: { in_progress: [bead("a-1", { lease_expires_at: PAST, notes: `PR: ${pr(1)}` })] },
    gh: { pulls: { [pr(1)]: "OPEN" } },
  });
  assert.deepEqual(sensor(ok, "stale-claims"), { code: 0, lines: [], err: "" });
});

test("merged-not-closed counts an open or in-progress bead whose noted pull request merged", () => {
  const w = world({
    beads: {
      open: [bead("m-1", { notes: `PR: ${pr(1)}` }), bead("m-2", { notes: `PR: ${pr(2)}` })],
      in_progress: [
        bead("m-3", { notes: `old\nPR: ${pr(9)}\nPR: ${pr(3)}` }),
        bead("m-4"),
        bead("m-5", { notes: `PR: ${pr(5)}`, labels: ["session:x"] }),
      ],
    },
    gh: {
      pulls: {
        [pr(1)]: "MERGED",
        [pr(2)]: "OPEN",
        [pr(3)]: "MERGED",
        [pr(5)]: "MERGED",
        [pr(9)]: "OPEN",
      },
    },
  });
  const r = sensor(w, "merged-not-closed");
  assert.equal(r.code, 1);
  assert.deepEqual(
    r.lines.map((l) => l.split(":")[0]),
    ["m-1", "m-3"],
  );
});

for (const [name, mk] of [
  [
    "merged-not-closed",
    () =>
      world({
        beads: { open: [bead("m-1", { notes: `PR: ${pr(1)}` })] },
        gh: { pulls: { [pr(1)]: "MERGED" } },
      }),
  ],
  [
    "ask-for-merged",
    () =>
      world({
        beads: {
          open: [bead("k-1", { labels: ["inbox", "inbox:merge"], external_ref: pr(1) })],
        },
        gh: { pulls: { [pr(1)]: "MERGED" } },
      }),
  ],
]) {
  test(`${name} exits 3, and counts nothing, when gh fails or is missing`, () => {
    const w = mk();
    const failing = sensor(w, name, { GH_FAIL: "1" });
    assert.equal(failing.code, 3);
    assert.deepEqual(failing.lines, []);
    assert.match(failing.err, /could not read the state of .*pull\/1/);
    rmSync(join(w.dir, "bin", "gh"));
    const missing = sensor(w, name);
    assert.equal(missing.code, 3);
    assert.deepEqual(missing.lines, []);
    assert.match(missing.err, /gh is not installed/);
  });
}

test("ready-without-ask counts an open, non-draft pull request with a ready verdict and no open merge bead", () => {
  const review = (body) => ({ body });
  const w = world({
    beads: { open: [bead("ask-1", { labels: ["inbox", "inbox:merge"], external_ref: pr(2) })] },
    gh: {
      prs: {
        [R]: [
          {
            number: 1,
            title: "ready, no ask",
            url: pr(1),
            isDraft: false,
            reviews: [review("**Hannett**\n✅ ready to merge")],
          },
          {
            number: 2,
            title: "ready, asked",
            url: pr(2),
            isDraft: false,
            reviews: [review("✅ ready to merge")],
          },
          {
            number: 3,
            title: "draft",
            url: pr(3),
            isDraft: true,
            reviews: [review("✅ ready to merge")],
          },
          {
            number: 4,
            title: "no verdict",
            url: pr(4),
            isDraft: false,
            reviews: [review("needs a fix")],
          },
          { number: 5, title: "no review", url: pr(5), isDraft: false, reviews: [] },
        ],
      },
    },
  });
  const r = sensor(w, "ready-without-ask");
  assert.equal(r.code, 1, r.err);
  assert.equal(r.lines.length, 1);
  assert.match(r.lines[0], /ready, no ask/);
  assert.match(r.lines[0], new RegExp(pr(1)));
});

test("ask-for-merged counts an open merge bead whose pull request merged or closed", () => {
  const merge = (id, n) => bead(id, { labels: ["inbox", "inbox:merge"], external_ref: pr(n) });
  const w = world({
    beads: {
      open: [
        merge("k-1", 1),
        merge("k-2", 2),
        merge("k-3", 3),
        bead("k-4", { external_ref: pr(1) }),
      ],
    },
    gh: { pulls: { [pr(1)]: "MERGED", [pr(2)]: "OPEN", [pr(3)]: "CLOSED" } },
  });
  const r = sensor(w, "ask-for-merged");
  assert.equal(r.code, 1);
  assert.deepEqual(
    r.lines.map((l) => l.split(":")[0]),
    ["k-1", "k-3"],
  );
});

test("finished-uncut counts an open milestone with nothing open, work closed and no tag for its version", () => {
  const ms = (title, open, closed) => ({
    title,
    open_issues: open,
    closed_issues: closed,
    created_at: "2026-11-01T00:00:00Z",
  });
  const w = world({
    gh: {
      milestones: {
        [R]: [
          ms("wheelhouse 0.5.0", 0, 4),
          ms("wheelhouse 0.4.0", 0, 9),
          ms("wheelhouse 0.6.0", 2, 1),
          ms("wheelhouse 0.7.0", 0, 0),
          ms("no version", 0, 3),
        ],
      },
      tags: { [R]: ["wheelhouse-v0.4.0", "wheelhouse-v0.40.0"] },
    },
  });
  const r = sensor(w, "finished-uncut");
  assert.equal(r.code, 1, r.err);
  assert.deepEqual(
    r.lines.map((l) => l.replace(`${R} `, "").split(" (")[0]),
    ["wheelhouse 0.5.0", "no version"],
  );
});

test("scope-after-open counts an issue milestoned on a later day than its open milestone was created", () => {
  const w = world({
    gh: {
      milestones: { [R]: [{ title: "0.5.0", created_at: "2026-11-10T09:00:00Z" }] },
      events: {
        [R]: [
          {
            event: "milestoned",
            created_at: "2026-11-10T11:00:00Z",
            milestone: { title: "0.5.0" },
            issue: { number: 1, title: "day one" },
          },
          {
            event: "milestoned",
            created_at: "2026-11-20T11:00:00Z",
            milestone: { title: "0.5.0" },
            issue: { number: 2, title: "late" },
          },
          {
            event: "milestoned",
            created_at: "2026-11-21T11:00:00Z",
            milestone: { title: "0.6.0" },
            issue: { number: 3, title: "other milestone" },
          },
          {
            event: "labeled",
            created_at: "2026-11-22T11:00:00Z",
            issue: { number: 4, title: "not a milestone" },
          },
        ],
      },
    },
  });
  const r = sensor(w, "scope-after-open");
  assert.equal(r.code, 1, r.err);
  assert.equal(r.lines.length, 1);
  assert.match(r.lines[0], /#2 late added to 0\.5\.0 on 2026-11-20/);
});

test("patrol-alive is 1 when the snapshot is older than twice its interval, 0 when fresh, and quiet with no snapshot", () => {
  const w = world();
  assert.deepEqual(sensor(w, "patrol-alive"), { code: 0, lines: [], err: "" });
  mkdirSync(join(w.wh, ".wheelhouse"));
  const snap = (at, interval) =>
    writeFileSync(
      join(w.wh, ".wheelhouse", "patrol.json"),
      JSON.stringify({ at, interval_minutes: interval, repos: {} }),
    );
  const now = 1_800_000_000;
  snap(now - 9 * 60, 5);
  assert.equal(sensor(w, "patrol-alive", { WHEELHOUSE_NOW: String(now) }).code, 0);
  snap(now - 11 * 60, 5);
  const r = sensor(w, "patrol-alive", { WHEELHOUSE_NOW: String(now) });
  assert.equal(r.code, 1);
  assert.match(r.lines[0], /11 minutes ago, over twice its 5-minute interval/);
});

test("guard-log counts the lines newer than the patrol's last run, and all of them with no snapshot", () => {
  const w = world();
  mkdirSync(join(w.wh, ".wheelhouse"));
  writeFileSync(
    join(w.wh, ".wheelhouse", "guard.log"),
    [
      "2026-11-27T09:00:00Z albarn shared-checkout git -C ../ynh checkout x",
      "2026-11-27T11:00:00Z albarn force bd close x --force",
      "2026-11-27T11:30:00Z gahan outward gh pr merge 1",
      "",
    ].join("\n"),
  );
  assert.equal(sensor(w, "guard-log").lines.length, 3);
  const at = Date.parse("2026-11-27T10:00:00Z") / 1000;
  writeFileSync(
    join(w.wh, ".wheelhouse", "patrol.json"),
    JSON.stringify({ at, interval_minutes: 5, repos: {} }),
  );
  const r = sensor(w, "guard-log");
  assert.equal(r.code, 1);
  assert.deepEqual(
    r.lines.map((l) => l.split(" ")[1]),
    ["albarn", "gahan"],
  );
  assert.deepEqual(sensor(world(), "guard-log"), { code: 0, lines: [], err: "" });
});

function runner(w, extra = [], env = {}) {
  const r = spawnSync("bash", [join(sensors, "run-record-sensors.sh"), "--dir", w.wh, ...extra], {
    encoding: "utf8",
    env: w.env(env),
  });
  const results = join(w.wh, ".wheelhouse", "record-sensors.json");
  return {
    code: r.status,
    out: r.stdout,
    err: r.stderr,
    results: existsSync(results) ? JSON.parse(readFileSync(results, "utf8")) : null,
  };
}

test("the runner keeps each count, reports a count that rose, and keeps a sensor's last count across an error", () => {
  const w = world({ beads: { in_progress: [bead("a-1", { lease_expires_at: PAST })] } });
  const first = runner(w, ["--interval", "7"]);
  assert.equal(first.code, 0, first.err);
  assert.deepEqual(JSON.parse(first.out), [], "the first run has nothing to compare with");
  assert.equal(first.results.interval_minutes, 7);
  assert.equal(first.results.sensors["stale-claims"].count, 1);
  assert.equal(first.results.sensors["merged-not-closed"].count, 0);
  assert.deepEqual(Object.keys(first.results.sensors).sort(), [
    "ask-for-merged",
    "finished-uncut",
    "guard-log",
    "merged-not-closed",
    "patrol-alive",
    "ready-without-ask",
    "scope-after-open",
    "stale-claims",
  ]);

  w.setBeads({
    in_progress: [bead("a-1", { lease_expires_at: PAST }), bead("a-2", { lease_expires_at: PAST })],
  });
  const second = runner(w);
  const rose = JSON.parse(second.out);
  assert.equal(rose.length, 1);
  assert.deepEqual(
    { ...rose[0], lines: undefined },
    { kind: "record-sensor-rose", sensor: "stale-claims", from: 1, to: 2, lines: undefined },
  );
  assert.equal(rose[0].lines.length, 2);

  const same = runner(w);
  assert.deepEqual(JSON.parse(same.out), [], "an unchanged count is not a rise");

  const broken = runner(w, [], { BD_FAIL: "1" });
  const s = broken.results.sensors["stale-claims"];
  assert.equal(s.count, null);
  assert.equal(s.previous, 2);
  assert.match(s.error, /bd could not list/);
  assert.deepEqual(JSON.parse(broken.out), []);

  const healed = runner(w);
  assert.deepEqual(JSON.parse(healed.out), [], "back at the last known count: not a rise");
  assert.equal(healed.results.sensors["stale-claims"].count, 2);
});

test("every sensor runs without ynh, and is declared in the manifest as an advisory command sensor", () => {
  const manifest = JSON.parse(
    readFileSync(join(plugin, ".agents", "harness", "plugin.json"), "utf8"),
  );
  for (const name of [
    "stale-claims",
    "merged-not-closed",
    "ready-without-ask",
    "ask-for-merged",
    "finished-uncut",
    "scope-after-open",
    "patrol-alive",
    "guard-log",
  ]) {
    const decl = manifest.sensors[name];
    assert.equal(decl.tolerance, "advisory", name);
    assert.equal(
      decl.ratchet,
      undefined,
      `${name} has no ratchet: the patrol compares with its last run`,
    );
    assert.match(decl.source.command, new RegExp(`sensors/record/${name}\\.sh`));
    assert.ok(existsSync(join(sensors, "record", `${name}.sh`)));
    const w = world();
    assert.ok(
      !spawnSync("bash", ["-c", "command -v ynh"], { env: w.env() }).stdout.length,
      "no ynh on the test's PATH",
    );
    const r = sensor(w, name);
    assert.notEqual(r.code, 127, `${name} needs a tool the test PATH lacks: ${r.err}`);
  }
});

// The patrol runs the runner, and the desk's wake shows its counts.
const patrolSh = join(plugin, "skills", "patrol", "scripts", "patrol.sh");

test("the patrol runs the record sensors on a saving run, reports a rise as a change and records at and interval_minutes", () => {
  const w = world({
    beads: { in_progress: [bead("a-1", { lease_expires_at: PAST })] },
    gh: { prs: { [R]: [] }, issues: { [R]: [] } },
  });
  // The patrol's own gh calls: pr list, issue list, repo view and run list.
  writeFileSync(
    join(w.dir, "bin", "gh"),
    ghStub.replace(
      `case "$1 $2" in`,
      `case "$1 $2" in
  "issue list") echo '[]' ;;
  "repo view") echo main ;;
  "run list") echo '[]' ;;`,
    ),
  );
  const patrol = (args = []) => {
    const r = spawnSync("bash", [patrolSh, "--dir", w.wh, "--interval", "9", ...args], {
      encoding: "utf8",
      env: w.env(),
    });
    return { code: r.status, changes: r.stdout ? JSON.parse(r.stdout) : null, err: r.stderr };
  };
  const first = patrol();
  assert.equal(first.code, 0, first.err);
  assert.deepEqual(first.changes, []);
  const snap = JSON.parse(readFileSync(join(w.wh, ".wheelhouse", "patrol.json"), "utf8"));
  assert.equal(snap.interval_minutes, 9);
  assert.ok(snap.at > 0);
  assert.equal(
    JSON.parse(readFileSync(join(w.wh, ".wheelhouse", "record-sensors.json"), "utf8")).sensors[
      "stale-claims"
    ].count,
    1,
  );

  w.setBeads({
    in_progress: [bead("a-1", { lease_expires_at: PAST }), bead("a-2", { lease_expires_at: PAST })],
  });
  const dry = patrol(["--dry-run"]);
  assert.deepEqual(dry.changes, [], "a dry run runs no sensors");
  const second = patrol();
  assert.equal(second.changes.length, 1);
  assert.equal(second.changes[0].kind, "record-sensor-rose");
  assert.equal(second.changes[0].sensor, "stale-claims");

  w.setBeads({
    in_progress: [
      bead("a-1", { lease_expires_at: PAST }),
      bead("a-2", { lease_expires_at: PAST }),
      bead("a-3", { lease_expires_at: PAST }),
    ],
  });
  assert.deepEqual(patrol(["--no-sensors"]).changes, [], "--no-sensors skips them");
});

test("an installed patrol finds the sensors in ynh's clone of the plugin, and WHEELHOUSE_SENSORS_DIR still overrides", () => {
  // The layout ynh makes: a seat's run folder holds only the plugin's skills; the plugin's own files
  // (sensors included) stay in a clone under $YNH_HOME/cache, which an installed harness's record names.
  const w = world({
    beads: { in_progress: [bead("a-1", { lease_expires_at: PAST })] },
    gh: { prs: { [R]: [] }, issues: { [R]: [] } },
  });
  writeFileSync(
    join(w.dir, "bin", "gh"),
    ghStub.replace(
      `case "$1 $2" in`,
      `case "$1 $2" in
  "issue list") echo '[]' ;;
  "repo view") echo main ;;
  "run list") echo '[]' ;;`,
    ),
  );
  const home = join(w.dir, "ynh-home");
  const clone = join(home, "cache", "eyelock--assistants--abc123");
  const copy = (from, to) => {
    mkdirSync(dirname(to), { recursive: true });
    spawnSync("cp", ["-R", from, to]);
  };
  copy(join(plugin, "sensors"), join(clone, "plugins", "wheelhouse", "sensors"));
  copy(join(plugin, "skills"), join(clone, "plugins", "wheelhouse", "skills"));
  const git = (...a) =>
    spawnSync("git", ["-C", clone, "-c", "user.email=a@b.c", "-c", "user.name=t", ...a], {
      encoding: "utf8",
    });
  git("init", "-q");
  git("add", "-A");
  git("commit", "-q", "-m", "plugin");
  const sha = git("rev-parse", "HEAD").stdout.trim();
  const record = (s) => {
    mkdirSync(join(home, "installed"), { recursive: true });
    writeFileSync(
      join(home, "installed", "local--reni.json"),
      JSON.stringify({
        id: "local/reni",
        resolved: [
          { git: "https://github.com/eyelock/assistants", path: "plugins/wheelhouse", sha: s },
        ],
      }),
    );
  };
  // The installed patrol: skills copied into the run folder, with no sensors folder anywhere near.
  const run = join(w.dir, "run", ".claude", "skills");
  copy(join(plugin, "skills", "patrol"), join(run, "patrol"));
  copy(join(plugin, "skills", "work-graph"), join(run, "work-graph"));
  const installed = join(run, "patrol", "scripts", "patrol.sh");
  const go = (extra = {}) => {
    const r = spawnSync("bash", [installed, "--dir", w.wh], {
      encoding: "utf8",
      env: w.env({ YNH_HOME: home, ...extra }),
    });
    return { code: r.status, err: r.stderr };
  };
  const counts = () => join(w.wh, ".wheelhouse", "record-sensors.json");

  record("0".repeat(40));
  const lost = go();
  assert.match(
    lost.err,
    /record sensors were not found/,
    "a clone at another commit is not the seat's plugin",
  );
  assert.equal(existsSync(counts()), false);

  record(sha);
  const found = go();
  assert.doesNotMatch(found.err, /not found/);
  assert.equal(JSON.parse(readFileSync(counts(), "utf8")).sensors["stale-claims"].count, 1);

  // WHEELHOUSE_SENSORS_DIR wins: an empty folder there means the runner is missing, so the next candidate runs.
  rmSync(counts());
  const over = go({ WHEELHOUSE_SENSORS_DIR: join(clone, "plugins", "wheelhouse", "sensors") });
  assert.equal(over.code, 0, over.err);
  assert.equal(existsSync(counts()), true);
});
