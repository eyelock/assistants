// A broken tool must never look like an empty inbox. inbox.sh show reads the humans' beads from bd
// and their notes from ynm; when either fails, show exits 3 and says what failed, still printing
// what the other returned, and the desk's wake says the inbox couldn't be read in full, never
// "Nothing waiting for the humans." Each case runs the real inbox.sh and wake.sh against a small
// Wheelhouse, with bd and ynm replaced by stubs that answer, or fail like a locked database or an
// unreachable store.
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
  humans: [
    { name: "Rook", command: "rook", pronouns: "they/them", default: true },
    { name: "Pat", command: "pat", email: "pat@example.com", pronouns: "they/them" },
  ],
};

const bead = {
  id: "hq-1",
  title: "Merge the changelog",
  issue_type: "task",
  priority: 1,
  created_by: "dalglish",
  external_ref: "https://github.com/example/widget/pull/12",
  dependent_count: 1,
};

// bd: `ready` fails when BD_BROKEN is set, else gives the merge to rook; anything else is empty.
const bdStub = `#!/bin/sh
if [ "$1" = ready ]; then
  if [ -n "$BD_BROKEN" ]; then echo "Error: database is locked" >&2; exit 1; fi
  case " $* " in *" rook "*) [ -z "$BD_EMPTY" ] && { echo '${JSON.stringify([bead])}'; exit 0; } ;; esac
fi
echo '[]'
`;

// ynm: recall fails when YNM_BROKEN is set, else finds nothing; anything else succeeds.
const ynmStub = `#!/bin/sh
if [ "$1" = recall ] && [ -n "$YNM_BROKEN" ]; then echo "ynm: cannot reach the memory store" >&2; exit 1; fi
echo '[]'
`;

function wheelhouse() {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-inbox-"));
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
  return dir;
}

function run(dir, script, args, env) {
  return spawnSync("bash", [script, ...args], {
    cwd: dir,
    encoding: "utf8",
    env: {
      ...process.env,
      PATH: `${join(dir, "bin")}:${process.env.PATH}`,
      WHEELHOUSE_HUMAN_EMAIL: "pat@example.com",
      BD_BROKEN: "",
      YNM_BROKEN: "",
      BD_EMPTY: "",
      ...env,
    },
  });
}

function scenario(env, check) {
  const dir = wheelhouse();
  try {
    const show = run(dir, inboxSh, ["show", "--dir", "."], env);
    const wake = run(dir, wakeSh, ["--seat", "hq", "--format", "text", "--no-sync"], env);
    assert.equal(wake.status, 0, wake.stderr);
    check(show, JSON.parse(show.stdout), wake.stdout);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("bd and ynm both failing: show exits 3, and the wake says the inbox couldn't be read", () => {
  scenario({ BD_BROKEN: "1", YNM_BROKEN: "1" }, (show, json, wake) => {
    assert.equal(show.status, 3);
    assert.match(show.stderr, /bd ready failed: Error: database is locked/);
    assert.match(show.stderr, /ynm recall failed: ynm: cannot reach the memory store/);
    assert.equal(json.empty, null);
    assert.deepEqual(
      json.errors,
      ["bd ready failed: Error: database is locked", "ynm recall failed: ynm: cannot reach the memory store"],
    );
    for (const h of json.humans) {
      assert.equal(h.beads, null);
      assert.equal(h.notes, null);
    }
    assert.match(wake, /The inbox could not be read in full:.*database is locked.*cannot reach the memory store/);
    assert.doesNotMatch(wake, /Nothing waiting/);
  });
});

test("only ynm failing: the wake still shows the beads bd returned, and says the notes couldn't be read", () => {
  scenario({ YNM_BROKEN: "1" }, (show, json, wake) => {
    assert.equal(show.status, 3);
    assert.deepEqual(json.errors, ["ynm recall failed: ynm: cannot reach the memory store"]);
    const rook = json.humans.find((h) => h.command === "rook");
    assert.equal(rook.beads[0].id, "hq-1");
    assert.equal(rook.notes, null);
    assert.match(wake, /The inbox could not be read in full:.*cannot reach the memory store/);
    assert.match(wake, /Merge the changelog: \[widget #12\]\(https:\/\/github\.com\/example\/widget\/pull\/12\)/);
    assert.match(wake, /Their notes couldn't be read/);
    assert.doesNotMatch(wake, /Nothing waiting/);
  });
});

test("only bd failing: the wake says the beads couldn't be read, never that nothing is waiting", () => {
  scenario({ BD_BROKEN: "1" }, (show, json, wake) => {
    assert.equal(show.status, 3);
    assert.deepEqual(json.errors, ["bd ready failed: Error: database is locked"]);
    assert.ok(json.humans.every((h) => h.beads === null && Array.isArray(h.notes)));
    assert.match(wake, /Their beads couldn't be read/);
    assert.doesNotMatch(wake, /Nothing waiting/);
  });
});

test("both working and nothing waiting: show exits 0, and the wake says nothing is waiting", () => {
  scenario({ BD_EMPTY: "1" }, (show, json, wake) => {
    assert.equal(show.status, 0, show.stderr);
    assert.deepEqual(json.errors, []);
    assert.equal(json.empty, true);
    assert.match(wake, /Nothing waiting for the humans\./);
    assert.doesNotMatch(wake, /could not be read/);
  });
});
