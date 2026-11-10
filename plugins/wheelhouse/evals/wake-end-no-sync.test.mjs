// wake.sh --end syncs what a session wrote (ynm sync, bd sync); --no-sync must skip both, as it does
// at wake. Each case runs the real wake.sh in a git repository with a remote, with bd and ynm
// stubbed to log every sync they are asked to do.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, existsSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const wakeSrc = join(plugin, "skills", "wake", "scripts", "wake.sh");

function run(args) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-end-no-sync-"));
  try {
    mkdirSync(join(dir, "scripts"));
    writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify({ seats: [{ name: "Hynde", group: "workers", command: "hynde", harness: ".", mandate: "Build." }], humans: [] }));
    mkdirSync(join(dir, "bin"));
    const log = join(dir, "calls.log");
    const stubs = {
      ynm: `#!/bin/sh\necho "ynm $*" >> "${log}"\nexit 0\n`,
      bd: `#!/bin/sh\necho "bd $*" >> "${log}"\nif [ "$1" = dolt ]; then echo '[{"name":"origin"}]'; fi\nexit 0\n`,
    };
    for (const [name, body] of Object.entries(stubs)) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    spawnSync("git", ["init", "-q"], { cwd: dir });
    spawnSync("git", ["remote", "add", "origin", "https://example.invalid/x.git"], { cwd: dir });
    const r = spawnSync("bash", [join(dir, "scripts", "wake.sh"), ...args], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}` },
    });
    const calls = existsSync(log) ? readFileSync(log, "utf8") : "";
    return { r, calls };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("--end syncs memory and the work graph", () => {
  const { r, calls } = run(["--end", "hynde"]);
  assert.equal(r.status, 0, r.stderr);
  assert.match(calls, /ynm sync/);
  assert.match(calls, /bd sync/);
  assert.deepEqual(JSON.parse(r.stdout).push, { memory: "pushed", work: "pushed" });
});

test("--end --no-sync performs no sync", () => {
  const { r, calls } = run(["--end", "hynde", "--no-sync"]);
  assert.equal(r.status, 0, r.stderr);
  assert.doesNotMatch(calls, /ynm sync/);
  assert.doesNotMatch(calls, /bd sync/);
  assert.deepEqual(JSON.parse(r.stdout).push, { memory: "skipped", work: "skipped" });
});

// A sync stub that sleeps, or fails with a message, to exercise the session-end time budget.
function runStub(ynmBody, env = {}, bdBody = "exit 0") {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-end-budget-"));
  try {
    mkdirSync(join(dir, "scripts"));
    writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify({ seats: [{ name: "Hynde", group: "workers", command: "hynde", harness: ".", mandate: "Build." }], humans: [] }));
    mkdirSync(join(dir, "bin"));
    writeFileSync(join(dir, "bin", "ynm"), `#!/bin/sh\n${ynmBody}\n`);
    writeFileSync(join(dir, "bin", "bd"), `#!/bin/sh\nif [ "$1" = dolt ]; then echo '[{"name":"origin"}]'; exit 0; fi\n${bdBody}\n`);
    chmodSync(join(dir, "bin", "ynm"), 0o755);
    chmodSync(join(dir, "bin", "bd"), 0o755);
    spawnSync("git", ["init", "-q"], { cwd: dir });
    spawnSync("git", ["remote", "add", "origin", "https://example.invalid/x.git"], { cwd: dir });
    return spawnSync("bash", [join(dir, "scripts", "wake.sh"), "--end", "hynde"], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, ...env, PATH: `${join(dir, "bin")}:${process.env.PATH}` },
    });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("--end with both syncs hanging finishes inside the 30-second session-end hook, errors kept", () => {
  const start = Date.now();
  const r = runStub("sleep 60; exit 0", { WHEELHOUSE_END_SYNC_SECS: "99" }, "sleep 60; exit 0");
  const secs = (Date.now() - start) / 1000;
  assert.equal(r.status, 0, r.stderr);
  assert.ok(secs < 30, `took ${secs}s, the hook allows 30`);
  const out = JSON.parse(r.stdout);
  assert.deepEqual(out.push, { memory: "timeout", work: "timeout" });
  assert.match(out.errors.memory, /^exit 142/);
  assert.match(out.errors.work, /^exit 142/);
});

test("--end reports a sync slower than the old 12 seconds, inside the budget, as pushed", () => {
  const r = runStub("sleep 14; exit 0");
  assert.equal(r.status, 0, r.stderr);
  const out = JSON.parse(r.stdout);
  assert.equal(out.push.memory, "pushed");
  assert.equal(out.errors, undefined);
});

test("--end reports a sync killed by the budget as a timeout", () => {
  const r = runStub("sleep 30; exit 0", { WHEELHOUSE_END_SYNC_SECS: "1" });
  assert.equal(r.status, 0, r.stderr);
  const out = JSON.parse(r.stdout);
  assert.equal(out.push.memory, "timeout");
  assert.match(out.errors.memory, /^exit 142/);
});

test("--end reports a failing sync with its exit code and first error line", () => {
  const r = runStub("echo 'rejected: non-fast-forward' >&2; echo second line >&2; exit 7");
  assert.equal(r.status, 0, r.stderr);
  const out = JSON.parse(r.stdout);
  assert.equal(out.push.memory, "failed");
  assert.equal(out.errors.memory, "exit 7: rejected: non-fast-forward");
});
