// memory-checks.sh holds the doctor's backend-dependent memory checks. Each case runs the real
// script in a scratch Wheelhouse, with memory.sh, ynm and bd stubbed: memory.sh answers the backend
// from $BACKEND (or fails with $BACKEND_FAIL) and a recall from $RECALL; ynm and bd answer from
// files in $STUB_DIR. PATH holds only jq, git, node and the stubs.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const script = join(plugin, "skills", "doctor", "scripts", "memory-checks.sh");

const memoryStub = `#!/bin/sh
case "$1" in
  backend) [ -z "$BACKEND_FAIL" ] || { echo "$BACKEND_FAIL" >&2; exit 2; }; echo "$BACKEND" ;;
  recall) printf '%s\\n' "$RECALL" ;;
esac
`;
const ynmStub = `#!/bin/sh
printf '%s\\n' "$*" >> "$STUB_DIR/ynm.log"
cat "$STUB_DIR/ynm.json"
`;
const bdStub = `#!/usr/bin/env node
const fs = require("node:fs");
const d = process.env.STUB_DIR;
const a = process.argv.slice(2).filter((x) => x !== "--readonly");
if (a[0] === "memories") {
  if (process.env.BAD_MEMORIES) process.exit(1);
  console.log(fs.readFileSync(d + "/memories.json", "utf8"));
} else if (a[0] === "dolt") console.log(process.env.REMOTE ? '[{"name":"origin"}]' : "[]");
`;

function setup({ memsh = true, wheelhouseJson, ynm = "[]", memories = "{}", withBd = true } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-memchecks-"));
  const wh = join(dir, "wh");
  const bin = join(dir, "bin");
  mkdirSync(bin);
  mkdirSync(join(wh, ".beads"), { recursive: true });
  mkdirSync(join(wh, "scripts"));
  for (const t of ["jq", "git", "node"]) {
    const found = spawnSync("sh", ["-c", `command -v ${t}`], { encoding: "utf8" }).stdout.trim();
    symlinkSync(found, join(bin, t));
  }
  const put = (path, body) => {
    writeFileSync(path, body);
    chmodSync(path, 0o755);
  };
  put(join(bin, "ynm"), ynmStub);
  if (withBd) put(join(bin, "bd"), bdStub);
  if (memsh) put(join(wh, "scripts", "memory.sh"), memoryStub);
  if (wheelhouseJson) writeFileSync(join(wh, "wheelhouse.json"), wheelhouseJson);
  writeFileSync(join(dir, "ynm.json"), ynm);
  writeFileSync(join(dir, "memories.json"), memories);
  // Beside the plugin the script finds the work-graph skill's memory.sh; a copy in a folder of its
  // own does not, which is a Wheelhouse with no memory.sh at all.
  let at = script;
  if (!memsh) {
    mkdirSync(join(dir, "skills", "doctor", "scripts"), { recursive: true });
    at = join(dir, "skills", "doctor", "scripts", "memory-checks.sh");
    copyFileSync(script, at);
    copyFileSync(join(plugin, "skills", "work-graph", "scripts", "wheelhouse-lib.sh"), join(dirname(at), "wheelhouse-lib.sh"));
  }
  return { dir, wh, bin, at };
}

function run(ctx, args, env = {}) {
  const r = spawnSync("/bin/bash", [ctx.at, ...args, "--dir", ctx.wh], {
    encoding: "utf8",
    env: { PATH: `${ctx.bin}:/usr/bin:/bin`, HOME: ctx.dir, STUB_DIR: ctx.dir, ...env },
  });
  rmSync(ctx.dir, { recursive: true, force: true });
  return r;
}

test("backend prints what memory.sh says", () => {
  const r = run(setup(), ["backend"], { BACKEND: "beads" });
  assert.equal(r.status, 0);
  assert.equal(r.stdout, "beads\n");
});

test("backend fails with memory.sh's reason when it can't be told", () => {
  const r = run(setup(), ["backend"], { BACKEND_FAIL: "wheelhouse.json is not JSON" });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /wheelhouse\.json is not JSON/);
});

test("with no memory.sh, a wheelhouse.json that names Beads is refused", () => {
  const r = run(setup({ memsh: false, wheelhouseJson: '{"memory":"beads"}' }), ["backend"]);
  assert.equal(r.status, 1);
  assert.match(r.stdout, /no memory\.sh/);
});

test("with no memory.sh and no memory key, the backend is ynm", () => {
  const r = run(setup({ memsh: false }), ["backend"]);
  assert.equal(r.status, 0);
  assert.equal(r.stdout, "ynm\n");
});

test("beads reports readable memory and a Dolt remote", () => {
  const ctx = setup({ memories: '{"schema_version":1,"a":"x","b":"y"}' });
  const r = run(ctx, ["beads"], { BACKEND: "beads", REMOTE: "1" });
  assert.equal(r.status, 0);
  const checks = JSON.parse(r.stdout);
  assert.deepEqual(checks.map((c) => [c.name, c.ok]), [["beads memory readable", true], ["beads memory shared", true]]);
  assert.equal(checks[0].detail, "2 memories");
});

test("beads warns when there is no Dolt remote, and errors when memories can't be read", () => {
  const r = run(setup({ memories: "not json" }), ["beads"], { BACKEND: "beads" });
  assert.equal(r.status, 0);
  const checks = JSON.parse(r.stdout);
  assert.deepEqual(checks.map((c) => [c.name, c.ok, c.level]), [
    ["beads memory readable", false, "error"],
    ["beads memory shared", false, "warn"],
  ]);
});

test("beads prints an empty list when bd is missing", () => {
  const r = run(setup({ withBd: false }), ["beads"], { BACKEND: "beads" });
  assert.equal(r.status, 0);
  assert.equal(r.stdout.trim(), "[]");
});

test("born with ynm: yes only for a pinned identity in the seat's namespace", () => {
  const pinned = '[{"namespace":"seat/wick","pinned":true}]';
  assert.equal(run(setup({ ynm: pinned }), ["born", "--seat", "wick"], { BACKEND: "ynm" }).stdout, "yes\n");
  const other = run(setup({ ynm: '[{"namespace":"seat/eno","pinned":true}]' }), ["born", "--seat", "wick"], { BACKEND: "ynm" });
  assert.equal(other.stdout, "no\n");
  const unpinned = run(setup({ ynm: '[{"namespace":"seat/wick","pinned":false}]' }), ["born", "--seat", "wick"], { BACKEND: "ynm" });
  assert.equal(unpinned.stdout, "no\n");
});

test("born with Beads reads the identity through memory.sh", () => {
  const yes = run(setup(), ["born", "--seat", "wick"], { BACKEND: "beads", RECALL: '[{"id":"seat/wick/identity"}]' });
  assert.equal(yes.stdout, "yes\n");
  const no = run(setup(), ["born", "--seat", "wick"], { BACKEND: "beads", RECALL: "[]" });
  assert.equal(no.stdout, "no\n");
});

test("human says whether memory holds human/<name>, on either backend", () => {
  assert.equal(run(setup({ ynm: '[{"id":"1"}]' }), ["human", "--name", "pat"], { BACKEND: "ynm" }).stdout, "yes\n");
  assert.equal(run(setup({ ynm: "[]" }), ["human", "--name", "pat"], { BACKEND: "ynm" }).stdout, "no\n");
  assert.equal(run(setup(), ["human", "--name", "pat"], { BACKEND: "beads", RECALL: '[{"id":"human/pat/note/1"}]' }).stdout, "yes\n");
});

test("a bad argument or command is refused with usage", () => {
  const bad = run(setup(), ["backend", "--bogus"], { BACKEND: "ynm" });
  assert.equal(bad.status, 1);
  assert.match(bad.stderr, /unknown argument: --bogus/);
  const none = run(setup(), ["bogus"], { BACKEND: "ynm" });
  assert.equal(none.status, 1);
  assert.match(none.stderr, /usage: memory-checks\.sh/);
});
