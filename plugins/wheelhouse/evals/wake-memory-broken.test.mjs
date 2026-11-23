// A failed or timed-out memory recall is not an empty memory: the wake says "Memory couldn't be read" and
// never tells an established seat to use the birth skill. A store that answers with nothing is a real first
// wake. Runs the real wake.sh in the installed layout with stand-ins for bd, ynm and gh.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const worker = { name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build." };

function wake(ynm, format, env = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-memory-broken-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify({ seats: [worker], humans: [] }));
    for (const [skill, files] of [
      ["wake", ["wake.sh", "sync.sh", "render-wake.jq"]],
      ["work-graph", ["memory.sh", "wheelhouse-lib.sh"]],
    ]) {
      mkdirSync(join(dir, "plugin", "skills", skill, "scripts"), { recursive: true });
      for (const f of files) copyFileSync(join(plugin, "skills", skill, "scripts", f), join(dir, "plugin", "skills", skill, "scripts", f));
    }
    mkdirSync(join(dir, "bin"));
    for (const [name, body] of [["bd", "#!/bin/sh\necho '[]'\n"], ["ynm", ynm], ["gh", "#!/bin/sh\nexit 1\n"]]) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    const args = [join(dir, "plugin", "skills", "wake", "scripts", "wake.sh"), "--seat", "hynde", "--no-sync"];
    if (format === "text") args.push("--format", "text");
    const r = spawnSync("bash", args, { cwd: dir, encoding: "utf8", env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "", WAKE_YNM_SECS: "2", ...env } });
    assert.equal(r.status, 0, r.stderr);
    return format === "text" ? r.stdout : JSON.parse(r.stdout);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const failing = "#!/bin/sh\necho 'ynm: cannot reach the memory store' >&2\nexit 1\n";
const hanging = "#!/bin/sh\nsleep 30\n";
const empty = "#!/bin/sh\necho '[]'\n";

test("a failed recall: the wake says memory couldn't be read and gives no birth instruction", () => {
  const text = wake(failing, "text");
  assert.match(text, /Memory couldn't be read/);
  assert.doesNotMatch(text, /This is your first session/);
  assert.doesNotMatch(text, /use the birth skill\. read/i);
  const json = wake(failing, "json");
  assert.equal(json.memoryRead, false);
  assert.equal(json.firstWake, false);
});

test("a recall that gives up reads the same way", () => {
  const json = wake(hanging, "json");
  assert.equal(json.memoryRead, false);
  assert.equal(json.firstWake, false);
});

test("a store that answers with nothing is a real first wake", () => {
  const text = wake(empty, "text");
  assert.match(text, /This is your first session as hynde/);
  assert.doesNotMatch(text, /Memory couldn't be read/);
  const json = wake(empty, "json");
  assert.equal(json.memoryRead, true);
  assert.equal(json.firstWake, true);
});
