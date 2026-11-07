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
