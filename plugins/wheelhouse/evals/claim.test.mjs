// claim.sh: a claim still happens, and warns when the bead's repo: label is outside the seat's
// specialities; an in-charter claim says nothing extra; --check warns without claiming; a refused
// claim prints no warning. Run against a small Wheelhouse with a bd stand-in that logs its calls.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const claimSh = join(here, "..", "skills", "work-graph", "scripts", "claim.sh");

const roster = {
  seats: [
    { name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk." },
    { name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build.", specialities: ["repo:ynh"] },
    { name: "Albarn", group: "workers", command: "albarn", harness: "harnesses/albarn", mandate: "Build.", specialities: ["repo:assistants", "repo:ynw"] },
    { name: "Gahan", group: "workers", command: "gahan", harness: "harnesses/gahan", mandate: "Build." },
  ],
  humans: [{ name: "Rook", command: "rook", default: true }],
};

// refuse: the claim is refused (bd update exits 1).
function run(args, { labels = ["repo:assistants"], refuse = false } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-claim-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "bin"));
    const log = join(dir, "bd.log");
    writeFileSync(
      join(dir, "bin", "bd"),
      `#!/bin/bash
echo "bd $*" >> "${log}"
case "$1" in
  update) ${refuse ? 'echo "already claimed" >&2; exit 1' : 'echo \'{"id":"x-1","status":"in_progress"}\''} ;;
  show) echo '[{"id":"x-1","labels":${JSON.stringify(labels)}}]' ;;
esac
`,
    );
    chmodSync(join(dir, "bin", "bd"), 0o755);
    const r = spawnSync("bash", [claimSh, ...args, "--dir", dir], {
      encoding: "utf8",
      env: { ...process.env, BEADS_ACTOR: "", PATH: `${join(dir, "bin")}:${process.env.PATH}` },
    });
    let calls = "";
    try {
      calls = readFileSync(log, "utf8");
    } catch {}
    return { ...r, calls };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("an out-of-charter claim still claims, and warns with the bead's repo and the seat's charter", () => {
  const r = run(["x-1", "--seat", "hynde"]);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.calls, /bd update x-1 --claim --actor hynde/);
  assert.match(r.stderr, /warning: x-1 is repo:assistants; your charter takes repo:ynh\./);
  assert.match(r.stdout, /in_progress/);
});

test("an in-charter claim prints nothing extra", () => {
  const r = run(["x-1", "--seat", "albarn"]);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.calls, /--claim/);
  assert.equal(r.stderr, "");
});

test("a seat with no specialities, a bead with no repo: label, and a seat not in the roster all stay silent", () => {
  assert.equal(run(["x-1", "--seat", "gahan"]).stderr, "");
  assert.equal(run(["x-1", "--seat", "hynde"], { labels: ["lang:go"] }).stderr, "");
  assert.equal(run(["x-1", "--seat", "nobody"]).stderr, "");
});

test("a refused claim passes bd's refusal through and prints no warning", () => {
  const r = run(["x-1", "--seat", "hynde"], { refuse: true });
  assert.equal(r.status, 1);
  assert.doesNotMatch(r.stderr, /warning/);
  assert.match(r.stderr, /already claimed/);
});

test("--check warns without claiming", () => {
  const r = run(["x-1", "--seat", "hynde", "--check"]);
  assert.equal(r.status, 0, r.stderr);
  assert.doesNotMatch(r.calls, /update/);
  assert.match(r.stderr, /warning: x-1 is repo:assistants/);
  assert.equal(run(["x-1", "--seat", "albarn", "--check"]).stderr, "");
});

test("bad arguments are refused", () => {
  assert.equal(run(["--seat", "hynde"]).status, 1);
  assert.equal(run(["x-1"], {}).status, 1);
});
