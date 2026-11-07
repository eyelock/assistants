// A merge goes in the inbox only once its pull request has left draft. inbox.sh assign --kind merge
// asks gh (stubbed here) and refuses a draft; without gh it warns and carries on.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const inboxSh = join(plugin, "skills", "work-graph", "scripts", "inbox.sh");

const roster = {
  seats: [{ name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk with the human." }],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};
const url = "https://github.com/example/widget/pull/12";

const bdStub = `#!/bin/sh
echo '{"id":"hq-9"}'
`;

const run = (gh) => {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-inbox-draft-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "bin"));
    const stubs = { bd: bdStub, ...(gh === null ? {} : { gh: `#!/bin/sh\n${gh}\n` }) };
    for (const [name, body] of Object.entries(stubs)) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    // With no gh stub, a PATH of bd's stub and the basics only, so a real gh can't answer.
    if (gh === null) {
      for (const b of ["bash", "jq", "tr", "grep", "head", "env", "dirname", "cat"]) {
        const which = spawnSync("sh", ["-c", `command -v ${b}`], { encoding: "utf8" }).stdout.trim();
        if (which) spawnSync("ln", ["-sf", which, join(dir, "bin", b)]);
      }
    }
    const path = gh === null ? join(dir, "bin") : `${join(dir, "bin")}:${process.env.PATH}`;
    return spawnSync(
      "bash",
      [inboxSh, "assign", "--dir", ".", "--from", "hq", "--kind", "merge", "--title", "Merge widget #12", "--url", url, "--repo", "widget"],
      { cwd: dir, encoding: "utf8", env: { ...process.env, PATH: path } },
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
};

test("a merge for a draft pull request is refused, saying why", () => {
  const r = run(`echo true`);
  assert.equal(r.status, 1, r.stderr);
  assert.match(r.stderr, /still a draft/);
  assert.equal(r.stdout, "");
});

test("a merge for a pull request out of draft is accepted", () => {
  const r = run(`echo false`);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(JSON.parse(r.stdout).id, "hq-9");
});

test("when gh fails, it warns and carries on", () => {
  const r = run(`exit 1`);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stderr, /warning/);
});

test("without gh, it warns and carries on", () => {
  const r = run(null);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stderr, /gh is not installed/);
});
