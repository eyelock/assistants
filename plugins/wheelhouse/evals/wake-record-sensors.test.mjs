// The desk's wake prints a "Record sensors" section from the patrol's .wheelhouse/record-sensors.json: one line
// per sensor above zero (with the count it rose from), one for a sensor that could not be counted, and a warning
// when the results are older than twice the patrol's interval. All zero and fresh prints nothing; so does no
// file (no patrol has run) and every seat but the desk. Runs the real wake.sh in the installed layout.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const desk = { name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk." };
const worker = {
  name: "Hynde",
  group: "workers",
  command: "hynde",
  harness: "harnesses/hynde",
  mandate: "Build.",
};

const sensor = (count, over = {}) => ({ count, previous: count, rose: false, lines: [], ...over });
const minutesAgo = (m) => Math.floor(Date.now() / 1000) - m * 60;

function wake(results, seat, format = "text") {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-record-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(
      join(dir, "skills", "roster", "assets", "roster.json"),
      JSON.stringify({
        seats: [desk, worker],
        humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
      }),
    );
    mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
    writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), "**Mandate:** Build.\n");
    for (const [skill, files] of [
      ["wake", ["wake.sh", "sync.sh", "render-wake.jq"]],
      ["work-graph", ["memory.sh", "wheelhouse-lib.sh", "inbox.sh"]],
    ]) {
      mkdirSync(join(dir, "plugin", "skills", skill, "scripts"), { recursive: true });
      for (const f of files)
        copyFileSync(
          join(plugin, "skills", skill, "scripts", f),
          join(dir, "plugin", "skills", skill, "scripts", f),
        );
    }
    if (results !== null) {
      mkdirSync(join(dir, ".wheelhouse"));
      writeFileSync(
        join(dir, ".wheelhouse", "record-sensors.json"),
        typeof results === "string" ? results : JSON.stringify(results),
      );
    }
    mkdirSync(join(dir, "bin"));
    for (const [name, body] of [
      ["bd", "#!/bin/sh\necho '[]'\n"],
      ["ynm", "#!/bin/sh\necho '[]'\n"],
      ["gh", "#!/bin/sh\nexit 1\n"],
    ]) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    const args = [
      join(dir, "plugin", "skills", "wake", "scripts", "wake.sh"),
      "--seat",
      seat,
      "--no-sync",
    ];
    if (format === "text") args.push("--format", "text");
    const r = spawnSync("bash", args, {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "" },
    });
    assert.equal(r.status, 0, r.stderr);
    return format === "text" ? r.stdout : JSON.parse(r.stdout);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("one line per sensor above zero, none for a zero, and the count a rising sensor rose from", () => {
  const text = wake(
    {
      at: minutesAgo(2),
      interval_minutes: 5,
      sensors: {
        "stale-claims": sensor(3, { previous: 1, rose: true }),
        "merged-not-closed": sensor(2),
        "ask-for-merged": sensor(0),
        "guard-log": sensor(0),
      },
    },
    "hq",
  );
  assert.match(text, /## Record sensors/);
  assert.match(text, /- stale-claims: 3 \(rose from 1\)/);
  assert.match(text, /- merged-not-closed: 2\n/);
  assert.doesNotMatch(text, /ask-for-merged|guard-log|patrol may be down/);
  assert.ok(text.indexOf("## Record sensors") < text.indexOf("## Who you are"));
});

test("a sensor that could not be counted is named, and results older than twice the interval warn that the patrol may be down", () => {
  const text = wake(
    {
      at: minutesAgo(30),
      interval_minutes: 5,
      sensors: {
        "finished-uncut": {
          count: null,
          previous: 1,
          rose: false,
          lines: [],
          error: "gh could not list x's milestones",
        },
      },
    },
    "hq",
  );
  assert.match(
    text,
    /patrol may be down:\*\* these counts are 30 minutes old, over twice its 5-minute interval/,
  );
  assert.match(text, /- finished-uncut: could not be counted \(gh could not list x's milestones\)/);
});

test("all zero and fresh, no file, and every seat but the desk print no section", () => {
  const zero = { at: minutesAgo(1), interval_minutes: 5, sensors: { "stale-claims": sensor(0) } };
  assert.doesNotMatch(wake(zero, "hq"), /Record sensors/);
  assert.doesNotMatch(wake(null, "hq"), /Record sensors/);
  assert.equal(wake(null, "hq", "json").recordSensors, null);
  const busy = { at: minutesAgo(1), interval_minutes: 5, sensors: { "stale-claims": sensor(4) } };
  assert.doesNotMatch(wake(busy, "hynde"), /Record sensors/);
  assert.equal(wake(busy, "hynde", "json").recordSensors, null);
});

test("a results file that is not JSON is said to be unreadable, never as nothing counted", () => {
  const text = wake("not json", "hq");
  assert.match(text, /## Record sensors/);
  assert.match(text, /record-sensors\.json could not be read/);
});
