// A seat on trial has its harness (harnesses/<command>/AGENTS.md) on the checked-out branch and
// no roster entry until the trial ends. It does real work, so it must be able to ask a human for a
// merge or a decision, as wake.sh and the doctor already recognise it. Each case runs the real
// inbox.sh against a small Wheelhouse, with bd stubbed.
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

const bdStub = `#!/bin/sh
if [ "$1" = create ]; then echo '{"id":"wh-1"}'; exit 0; fi
echo '[]'
`;

function inbox(args, check) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-inbox-trial-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "harnesses", "newcomer"), { recursive: true });
    writeFileSync(join(dir, "harnesses", "newcomer", "AGENTS.md"), "**Mandate:** Build.\n");
    mkdirSync(join(dir, "harnesses", "empty"), { recursive: true });
    mkdirSync(join(dir, "bin"));
    writeFileSync(join(dir, "bin", "bd"), bdStub);
    chmodSync(join(dir, "bin", "bd"), 0o755);
    const out = spawnSync("bash", [inboxSh, ...args, "--dir", "."], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}` },
    });
    check(out);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("assign: a seat on trial (harness on the branch, no roster entry) may ask", () => {
  inbox(["assign", "--title", "Decide the name", "--from", "newcomer", "--kind", "decision"], (out) => {
    assert.equal(out.status, 0, out.stderr);
    assert.equal(JSON.parse(out.stdout).askedBy, "newcomer");
  });
});

test("assign: a command with no roster entry and no harness AGENTS.md is refused, saying how a trial seat counts", () => {
  for (const from of ["stranger", "empty"]) {
    inbox(["assign", "--title", "Decide the name", "--from", from], (out) => {
      assert.equal(out.status, 1);
      assert.match(out.stderr, new RegExp(`${from} is not a seat in the roster, and there is no harnesses/${from}/AGENTS.md`));
    });
  }
});

test("assign: a --from that is not a plain command never reaches the filesystem", () => {
  inbox(["assign", "--title", "Decide the name", "--from", "../harnesses/newcomer"], (out) => {
    assert.equal(out.status, 1);
    assert.match(out.stderr, /is not a seat in the roster/);
  });
});

test("close: a seat on trial is not the desk", () => {
  inbox(["close", "wh-1", "--reason", "done", "--from", "newcomer"], (out) => {
    assert.notEqual(out.status, 0);
  });
});
