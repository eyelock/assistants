// inbox.sh close closes a human's inbox bead with a note, forced, and refuses anything else.
// Each case runs the real inbox.sh against a small Wheelhouse, with bd stubbed to log its calls.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const inboxSh = join(plugin, "skills", "work-graph", "scripts", "inbox.sh");

const roster = {
  seats: [
    { name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk with the human." },
    { name: "Dal", group: "workers", command: "dal", harness: "harnesses/dal", mandate: "Build." },
  ],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};

const beads = {
  "hq-1": { id: "hq-1", status: "open", assignee: "rook", labels: ["inbox", "inbox:merge"] },
  "hq-2": { id: "hq-2", status: "open", assignee: "dal", labels: ["inbox"] },
  "hq-3": { id: "hq-3", status: "open", assignee: "rook", labels: ["repo:ynh"] },
  "hq-4": { id: "hq-4", status: "closed", assignee: "rook", labels: ["inbox"] },
};

function run(args) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-inbox-close-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "bin"));
    const stub = `#!/bin/sh
echo "$@" >> "${dir}/bd.log"
case "$1" in
  show) case "$2" in
${Object.entries(beads)
  .map(([k, v]) => `    ${k}) echo '${JSON.stringify([v])}'; exit 0 ;;`)
  .join("\n")}
    *) exit 1 ;; esac ;;
  close) echo closed; exit 0 ;;
esac
exit 1
`;
    writeFileSync(join(dir, "bin", "bd"), stub);
    chmodSync(join(dir, "bin", "bd"), 0o755);
    const env = { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "" };
    const r = spawnSync("bash", [inboxSh, ...args, "--dir", "."], { cwd: dir, encoding: "utf8", env });
    let log = "";
    try {
      log = readFileSync(join(dir, "bd.log"), "utf8");
    } catch {}
    return { r, log };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("close closes a human's inbox bead with the note, forced, as the asking seat", () => {
  for (const verb of ["close", "done"]) {
    const { r, log } = run([verb, "--id", "hq-1", "--note", "Merged by the human", "--from", "hq"]);
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(JSON.parse(r.stdout), { id: "hq-1", closedBy: "hq", note: "Merged by the human" });
    assert.match(log, /^close hq-1 --reason Merged by the human --force --actor hq$/m);
  }
});

test("close refuses a seat's bead, a bead outside the inbox, a closed one and missing arguments", () => {
  const cases = [
    [["--id", "hq-2", "--note", "x", "--from", "hq"], /not assigned to a human/],
    [["--id", "hq-3", "--note", "x", "--from", "hq"], /not an inbox bead/],
    [["--id", "hq-4", "--note", "x", "--from", "hq"], /already closed/],
    [["--id", "hq-9", "--note", "x", "--from", "hq"], /no bead hq-9/],
    [["--note", "x", "--from", "hq"], /needs --id/],
    [["--id", "hq-1", "--from", "hq"], /needs --note/],
    [["--id", "hq-1", "--note", "x", "--from", "nobody"], /not a seat/],
  ];
  for (const [args, msg] of cases) {
    const { r, log } = run(["close", ...args]);
    assert.equal(r.status, 1, `${args.join(" ")}: ${r.stderr}`);
    assert.match(r.stderr, msg);
    assert.doesNotMatch(log, /^close /m);
  }
});
