// With wheelhouse.json {"memory": "beads"} wake.sh reads the seat's memory from Beads through
// memory.sh (never calling ynm), shows the Wheelhouse's shared facts, prints the Beads retire
// command, and syncs once for memory and work. With ynm the retire command is ynm's.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const wakeSrc = join(plugin, "skills", "wake", "scripts", "wake.sh");
const memorySrc = join(plugin, "skills", "work-graph", "scripts", "memory.sh");

const memories = {
  schema_version: 1,
  "seat/hynde/identity": "I am Hynde.",
  "seat/hynde/handoff": "Picking up b-9.",
  "seat/hynde/kudos/20261101T100000Z-marr": "Thanks for b-2.",
  "seat/hynde/close-note/20261102T100000Z-b-3": "Surprised: a.\nSharp edges: b.",
  "wheelhouse/branching": "Pull requests target develop.",
};

function wake(memory, { args = ["hynde", "--format", "json"], end = false, remote = true } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-beads-"));
  try {
    mkdirSync(join(dir, "scripts"));
    writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
    writeFileSync(join(dir, "scripts", "memory.sh"), readFileSync(memorySrc));
    writeFileSync(join(dir, "wheelhouse.json"), JSON.stringify({ tasks: "beads", memory }));
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify({ seats: [{ name: "Hynde", group: "workers", command: "hynde", harness: ".", mandate: "Build." }], humans: [] }));
    mkdirSync(join(dir, "bin"));
    const log = join(dir, "calls.log");
    const stubs = {
      ynm: `#!/bin/sh\necho "ynm $*" >> "${log}"\nif [ "$1" = recall ]; then echo '[]'; fi\nexit 0\n`,
      bd: `#!/bin/sh
echo "bd $*" >> "${log}"
case "$1 $2" in
  "--readonly memories") cat <<'JSON'
${JSON.stringify(memories)}
JSON
  ;;
  "dolt remote") echo '[{"name":"origin"}]' ;;
  *) [ "$1" = memories ] || echo '[]' ;;
esac
exit 0
`,
    };
    for (const [name, body] of Object.entries(stubs)) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    spawnSync("git", ["init", "-q"], { cwd: dir });
    if (remote) spawnSync("git", ["remote", "add", "origin", "https://example.invalid/x.git"], { cwd: dir });
    const r = spawnSync("bash", [join(dir, "scripts", "wake.sh"), ...(end ? ["--end", "hynde"] : args)], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}` },
    });
    return { r, calls: existsSync(log) ? readFileSync(log, "utf8") : "" };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("beads: identity, handoff, kudos, close notes and shared facts come from Beads, never ynm", () => {
  const { r, calls } = wake("beads");
  assert.equal(r.status, 0, r.stderr);
  const out = JSON.parse(r.stdout);
  assert.equal(out.backend, "beads");
  assert.equal(out.identity, "I am Hynde.");
  assert.equal(out.handoff, "Picking up b-9.");
  assert.equal(out.handoffId, "seat/hynde/handoff");
  assert.deepEqual(out.kudos, ["Thanks for b-2."]);
  assert.deepEqual(out.closeNotes, [{ bead: "b-3", note: "Surprised: a.\nSharp edges: b." }]);
  assert.deepEqual(out.facts, ["Pull requests target develop."]);
  assert.doesNotMatch(calls, /^ynm /m);
});

test("beads: the text block shows the facts and the bd forget retire command", () => {
  const { r } = wake("beads", { args: ["hynde", "--format", "text", "--no-sync"] });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /## What the Wheelhouse knows\n\n?- Pull requests target develop\./);
  assert.match(r.stdout, /`bd forget -- seat\/hynde\/handoff`/);
  assert.doesNotMatch(r.stdout, /ynm forget/);
});

test("ynm: the retire command is ynm's and there are no shared facts to show", () => {
  const { r } = wake("ynm", { args: ["hynde", "--format", "text", "--no-sync"] });
  assert.equal(r.status, 0, r.stderr);
  assert.doesNotMatch(r.stdout, /What the Wheelhouse knows/);
});

test("beads: one bd sync stands for memory and work at wake, and --end reports both from it", () => {
  const wakeRun = wake("beads", { remote: false });
  assert.deepEqual(JSON.parse(wakeRun.r.stdout).sync, { memory: "synced", work: "synced" });
  assert.equal((wakeRun.calls.match(/^bd sync/gm) ?? []).length, 1);
  const endRun = wake("beads", { end: true });
  assert.equal(endRun.r.status, 0, endRun.r.stderr);
  assert.deepEqual(JSON.parse(endRun.r.stdout).push, { memory: "pushed", work: "pushed" });
  assert.equal((endRun.calls.match(/^bd sync/gm) ?? []).length, 1);
  assert.doesNotMatch(endRun.calls, /^ynm /m);
});

test("beads: with --no-sync both syncs are skipped", () => {
  const { r } = wake("beads", { args: ["hynde", "--format", "json", "--no-sync"] });
  assert.deepEqual(JSON.parse(r.stdout).sync, { memory: "skipped", work: "skipped" });
});
