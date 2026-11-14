// The desk's wake prints a "Wake first" section after the inbox, naming the roster's ci-watcher and
// releaser seats; a desk with neither role, and every other seat, gets none. Runs the real wake.sh in the
// installed layout (wake.sh, sync.sh and render-wake.jq in the wake skill; the rest in work-graph).
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const desk = { name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk." };
const worker = { name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build." };
const reni = { name: "Reni", group: "standing", command: "reni", harness: "harnesses/reni", mandate: "Watch.", role: "ci-watcher" };
const entwistle = { name: "Entwistle", group: "standing", command: "entwistle", harness: "harnesses/entwistle", mandate: "Release.", role: "releaser" };

function wake(seats, seat, format) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-first-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify({ seats, humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }] }));
    mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
    writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), "**Mandate:** Build.\n");
    for (const [skill, files] of [
      ["wake", ["wake.sh", "sync.sh", "render-wake.jq"]],
      ["work-graph", ["memory.sh", "wheelhouse-lib.sh", "inbox.sh"]],
    ]) {
      mkdirSync(join(dir, "plugin", "skills", skill, "scripts"), { recursive: true });
      for (const f of files) copyFileSync(join(plugin, "skills", skill, "scripts", f), join(dir, "plugin", "skills", skill, "scripts", f));
    }
    mkdirSync(join(dir, "bin"));
    for (const [name, body] of [["bd", "#!/bin/sh\necho '[]'\n"], ["ynm", "#!/bin/sh\necho '[]'\n"], ["gh", "#!/bin/sh\nexit 1\n"]]) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    const args = [join(dir, "plugin", "skills", "wake", "scripts", "wake.sh"), "--seat", seat, "--no-sync"];
    if (format === "text") args.push("--format", "text");
    const r = spawnSync("bash", args, { cwd: dir, encoding: "utf8", env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "" } });
    assert.equal(r.status, 0, r.stderr);
    return format === "text" ? r.stdout : JSON.parse(r.stdout);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("a desk with both roles: the section follows the inbox and names both, CI watcher first", () => {
  const text = wake([desk, entwistle, reni, worker], "hq", "text");
  const section = "Wake first: Reni (open PRs and CI), Entwistle (release in hand: next on the route).";
  assert.ok(text.includes(`## Wake first\n\n${section}`), text);
  assert.ok(text.indexOf("## For the humans") < text.indexOf("## Wake first"), "after the inbox");
  assert.ok(text.indexOf("## Wake first") < text.indexOf("## Who you are"), "before who you are");
  assert.match(text, /don't check GitHub yourself/);
  const json = wake([desk, entwistle, reni, worker], "hq", "json");
  assert.deepEqual(json.wakeFirst.map((s) => [s.command, s.role]), [["reni", "ci-watcher"], ["entwistle", "releaser"]]);
});

test("a desk with neither role prints no section, and the JSON has an empty list", () => {
  assert.doesNotMatch(wake([desk, worker], "hq", "text"), /Wake first/);
  assert.deepEqual(wake([desk, worker], "hq", "json").wakeFirst, []);
});

test("a desk with one role names only that one", () => {
  const text = wake([desk, reni], "hq", "text");
  assert.match(text, /Wake first: Reni \(open PRs and CI\)\./);
  assert.doesNotMatch(text, /Entwistle/);
});

test("another seat's wake has no section, and wakeFirst is null", () => {
  assert.doesNotMatch(wake([desk, reni, entwistle, worker], "hynde", "text"), /Wake first/);
  assert.equal(wake([desk, reni, entwistle, worker], "hynde", "json").wakeFirst, null);
});
