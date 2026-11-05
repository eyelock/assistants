// A report sorts after the work a human has to do. inbox.sh show lists a human's ready beads with
// their kind (from the inbox:<kind> label), reports last whatever their priority, and the desk's
// wake shows reports under their own "Reports:" line, after the merges, reviews and decisions.
// Each case runs the real inbox.sh and wake.sh against a small Wheelhouse, with bd and ynm stubbed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const inboxSh = join(plugin, "skills", "work-graph", "scripts", "inbox.sh");
const wakeSh = join(plugin, "skills", "wake", "scripts", "wake.sh");

const roster = {
  seats: [{ name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk with the human." }],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};

const bead = (id, title, kind, priority, ref) => ({
  id,
  title,
  issue_type: "task",
  priority,
  created_by: "dalglish",
  labels: ["inbox", ...(kind ? [`inbox:${kind}`] : [])],
  external_ref: ref ?? "",
  dependent_count: 0,
});

// Out of order on purpose: an urgent report (priority 0) and a plain bead with no kind.
const ready = [
  bead("hq-1", "Weekly roadmap report", "report", 0),
  bead("hq-2", "Decide the release date", "decision", 2),
  bead("hq-3", "Milestone moved: 1.2 slips a week", "report", 3),
  bead("hq-4", "Merge widget #12", "merge", 1, "https://github.com/example/widget/pull/12"),
  bead("hq-5", "Renew the signing key", null, 2),
];

const bdStub = `#!/bin/sh
if [ "$1" = ready ]; then
  case " $* " in *" rook "*) echo '${JSON.stringify(ready)}'; exit 0 ;; esac
fi
echo '[]'
`;
const ynmStub = `#!/bin/sh
echo '[]'
`;

test("show lists reports after the rest, whatever their priority, and the wake under Reports:", () => {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-inbox-report-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    writeFileSync(join(dir, "AGENTS.md"), "**Mandate:** Talk with the human.\n");
    mkdirSync(join(dir, "bin"));
    for (const [name, body] of [
      ["bd", bdStub],
      ["ynm", ynmStub],
    ]) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    const env = { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, WHEELHOUSE_HUMAN_EMAIL: "" };
    const show = spawnSync("bash", [inboxSh, "show", "--dir", "."], { cwd: dir, encoding: "utf8", env });
    assert.equal(show.status, 0, show.stderr);
    const rook = JSON.parse(show.stdout).humans.find((h) => h.command === "rook");
    assert.deepEqual(
      rook.beads.map((b) => [b.id, b.kind]),
      [
        ["hq-4", "merge"],
        ["hq-2", "decision"],
        ["hq-5", null],
        ["hq-1", "report"],
        ["hq-3", "report"],
      ],
    );

    const wake = spawnSync("bash", [wakeSh, "--seat", "hq", "--format", "text", "--no-sync"], {
      cwd: dir,
      encoding: "utf8",
      env,
    });
    assert.equal(wake.status, 0, wake.stderr);
    const block = wake.stdout;
    const at = (s) => {
      const i = block.indexOf(s);
      assert.ok(i >= 0, `the wake shows ${s}`);
      return i;
    };
    assert.ok(at("Merge widget #12") < at("Decide the release date"));
    assert.ok(at("Renew the signing key") < at("Reports:"));
    assert.ok(at("Reports:") < at("Weekly roadmap report"));
    assert.ok(at("Weekly roadmap report") < at("Milestone moved"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
