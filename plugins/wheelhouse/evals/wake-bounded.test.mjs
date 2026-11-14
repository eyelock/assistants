// wake.sh bounds every bd, memory.sh and gh call, so a wake never hangs when bd is held by other
// seats, and says plainly when the work graph could not be read. Each case runs the real wake.sh
// (and memory.sh, which it needs beside it) in a throwaway Wheelhouse, with stand-ins for bd, ynm
// and gh on the path. The slow bd sleeps far past the limits set here, so a wake that does not
// bound its calls fails the time check.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, existsSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const wakeSrc = join(plugin, "skills", "wake", "scripts", "wake.sh");
const memorySrc = join(plugin, "skills", "work-graph", "scripts", "memory.sh");

function run(args, { mode, env = {}, remote = false } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-bounded-"));
  try {
    mkdirSync(join(dir, "scripts"));
    writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
    for (const f of ["sync.sh", "render-wake.jq"]) writeFileSync(join(dir, "scripts", f), readFileSync(wakeSrc.replace(/wake\.sh$/, f)));
    writeFileSync(join(dir, "scripts", "memory.sh"), readFileSync(memorySrc));
    writeFileSync(join(dir, "scripts", "wheelhouse-lib.sh"), readFileSync(join(plugin, "skills", "work-graph", "scripts", "wheelhouse-lib.sh")));
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify({ seats: [{ name: "Tess", group: "workers", command: "tess", harness: ".", mandate: "Build." }], humans: [] }));
    mkdirSync(join(dir, "bin"));
    const log = join(dir, "calls.log");
    const stubs = {
      // slow: every call sleeps 60s (a held lock); slowsync: the remote check is slow, the sync hangs; ok: answers at once. A Dolt remote exists only when asked.
      bd: `#!/bin/bash
echo "bd $*" >> "${log}"
[ "$BD_MODE" = slow ] && sleep 60
# slowsync: the Dolt-remote check answers after 2s, then every other call hangs.
if [ "$BD_MODE" = slowsync ]; then case "$*" in *"dolt remote"*) sleep 2 ;; *) sleep 60 ;; esac; fi
case "$*" in
  *"dolt remote"*) echo '${remote ? '[{"name":"origin"}]' : "[]"}' ;;
  *"--status in_progress"*) if [ "$BD_MODE" = retro ]; then echo '[{"id":"r1","title":"Tess retro","notes":"","labels":["retro","retro:tess"]}]'; else echo '[{"title":"Mine","notes":""}]'; fi ;;
  *"ready --unassigned"*) echo '[{"title":"Spare","priority":1,"issue_type":"task"}]' ;;
  *) echo '[]' ;;
esac
`,
      ynm: `#!/bin/sh\necho '[]'\n`,
      gh: `#!/bin/sh\nexit 1\n`,
    };
    for (const [name, body] of Object.entries(stubs)) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    spawnSync("git", ["init", "-q"], { cwd: dir });
    const start = Date.now();
    const r = spawnSync("bash", [join(dir, "scripts", "wake.sh"), ...args], {
      cwd: dir,
      encoding: "utf8",
      timeout: 50000,
      env: {
        ...process.env,
        PATH: `${join(dir, "bin")}:${process.env.PATH}`,
        BD_MODE: mode,
        WAKE_BD_SECS: "2",
        WAKE_SYNC_SECS: "2",
        WAKE_INBOX_SECS: "2",
        WAKE_YNM_SECS: "2",
        ...env,
      },
    });
    const calls = existsSync(log) ? readFileSync(log, "utf8") : "";
    return { r, calls, secs: (Date.now() - start) / 1000 };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("a locked bd: the wake finishes in bounded time and says the work graph couldn't be read", () => {
  const { r, calls, secs } = run(["tess", "--format", "text"], { mode: "slow" });
  assert.equal(r.status, 0, r.stderr);
  assert.ok(secs < 20, `took ${secs}s, not 60s a call`);
  assert.match(r.stdout, /couldn't be read \(bd busy\)/);
  assert.doesNotMatch(r.stdout, /Nothing assigned to you/);
  assert.match(r.stdout, /## Who you are/);
  const reads = calls.split("\n").filter((l) => /^bd (list|ready)/.test(l));
  assert.ok(reads.length <= 1, `one wait, not one per read: ${reads.length} read calls`);
});

test("a locked bd: the block names the retro bead as missing, not absent", () => {
  // The seat has a retro bead (the stub answers it in a free bd), but with bd locked nothing is read.
  const { r } = run(["tess", "--format", "text"], { mode: "slow" });
  assert.match(r.stdout, /your retro bead \(if you have one\)/);
  assert.doesNotMatch(r.stdout, /## Your retro/);
  // The same seat with a free bd and a retro bead shows it, so the line above is not hiding it.
  const free = run(["tess", "--format", "text"], { mode: "retro" });
  assert.match(free.r.stdout, /## Your retro/);
  assert.doesNotMatch(free.r.stdout, /couldn't be read/);
});

test("a locked bd: JSON workRead is false", () => {
  const { r } = run(["tess"], { mode: "slow" });
  assert.equal(JSON.parse(r.stdout).workRead, false);
});

test("a timed-out Dolt-remote check reads as a failed work sync, not 'no remote'", () => {
  const { r } = run(["tess", "--format", "text"], { mode: "slow" });
  assert.match(r.stdout, /Not synced/);
});

test("a free bd: the work reads as before, nothing is flagged", () => {
  const { r } = run(["tess", "--format", "text"], { mode: "ok" });
  assert.equal(r.status, 0, r.stderr);
  assert.doesNotMatch(r.stdout, /couldn't be read/);
  assert.doesNotMatch(r.stdout, /Not synced/);
  assert.match(r.stdout, /Spare/);
  assert.equal(JSON.parse(run(["tess"], { mode: "ok" }).r.stdout).workRead, true);
});

test("--end with a locked bd is bounded by the end budget and still prints its JSON", () => {
  const { r, secs } = run(["--end", "tess"], { mode: "slow", remote: true, env: { WAKE_SYNC_SECS: "30", WHEELHOUSE_END_SYNC_SECS: "3" } });
  assert.equal(r.status, 0, r.stderr);
  assert.ok(secs < 12, `took ${secs}s`);
  assert.equal(JSON.parse(r.stdout).push.work, "timeout");
});

test("--end: a slow Dolt-remote check leaves the sync only the rest of the budget", () => {
  // Budget 9: the check may take 3s and takes 2, so the sync gets about 6s, 8s in all. A sync
  // given the whole budget again would end near 11s, past the 9s the budget promises.
  const { r, secs } = run(["--end", "tess"], { mode: "slowsync", remote: true, env: { WAKE_SYNC_SECS: "30", WHEELHOUSE_END_SYNC_SECS: "9" } });
  assert.equal(r.status, 0, r.stderr);
  assert.ok(secs < 9.5, `took ${secs}s, over the 9s budget`);
  assert.equal(JSON.parse(r.stdout).push.work, "timeout");
});
