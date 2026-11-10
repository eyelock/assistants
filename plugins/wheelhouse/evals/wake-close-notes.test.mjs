// A seat's wake shows the latest three close notes it wrote (ynm memories tagged close-note in
// seat/<command>, subject the bead id), newest first, and shows nothing about them when it has
// none. Each case runs the real wake.sh against a small Wheelhouse with bd and ynm stubbed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const wakeSrc = join(plugin, "skills", "wake", "scripts", "wake.sh");
const memorySrc = join(plugin, "skills", "work-graph", "scripts", "memory.sh");

const roster = {
  seats: [{ name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build." }],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};

const note = (id, bead, content, updatedAt) => ({ memoryId: id, subject: bead, content, updatedAt, tags: ["close-note"] });
const four = [
  note("N1", "b-1", "Surprised: oldest.\nSharp edges: one.", "2026-11-01T10:00:00Z"),
  note("N2", "b-2", "Surprised: second.\nSharp edges: two.", "2026-11-02T10:00:00Z"),
  note("N3", "b-3", "Surprised: third.\nSharp edges: three.", "2026-11-03T10:00:00Z"),
  note("N4", "b-4", "Surprised: newest.\nSharp edges: four.", "2026-11-04T10:00:00Z"),
];

function ynmStub(notes) {
  return `#!/bin/sh
if [ "$1" = recall ]; then
  case " $* " in
    *" seat/hynde "*) jq -c '. + [{"memoryId":"M1","content":"I am Hynde.","tags":["identity"]}]' <<'JSON'
${JSON.stringify(notes)}
JSON
    exit 0 ;;
  esac
fi
echo '[]'
`;
}

function wake(notes, format) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-close-notes-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
    writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), "**Mandate:** Build.\n");
    mkdirSync(join(dir, "scripts"));
    writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
    writeFileSync(join(dir, "scripts", "memory.sh"), readFileSync(memorySrc));
    writeFileSync(join(dir, "scripts", "wheelhouse-lib.sh"), readFileSync(join(plugin, "skills", "work-graph", "scripts", "wheelhouse-lib.sh")));
    mkdirSync(join(dir, "bin"));
    for (const [name, body] of [["bd", "#!/bin/sh\necho '[]'\n"], ["ynm", ynmStub(notes)]]) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    return spawnSync("bash", [join(dir, "scripts", "wake.sh"), "--seat", "hynde", "--format", format, "--no-sync"], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "" },
    });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("the wake shows the latest three close notes, newest first, each on one line", () => {
  const r = wake(four, "text");
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /## Your close notes/);
  const shown = r.stdout.split("## Your close notes")[1].split("##")[0];
  assert.match(shown, /- b-4: Surprised: newest\. \/ Sharp edges: four\./);
  assert.match(shown, /- b-3: /);
  assert.match(shown, /- b-2: /);
  assert.doesNotMatch(shown, /b-1/);
  assert.ok(shown.indexOf("b-4") < shown.indexOf("b-3") && shown.indexOf("b-3") < shown.indexOf("b-2"));
});

test("the JSON carries closeNotes as {bead, note}", () => {
  const r = wake(four, "json");
  assert.equal(r.status, 0, r.stderr);
  const { closeNotes } = JSON.parse(r.stdout);
  assert.equal(closeNotes.length, 3);
  assert.deepEqual(closeNotes[0], { bead: "b-4", note: "Surprised: newest.\nSharp edges: four." });
});

test("with no close notes the text shows no such section and the JSON an empty list", () => {
  const text = wake([], "text");
  assert.equal(text.status, 0, text.stderr);
  assert.doesNotMatch(text.stdout, /close notes/i);
  assert.deepEqual(JSON.parse(wake([], "json").stdout).closeNotes, []);
});
