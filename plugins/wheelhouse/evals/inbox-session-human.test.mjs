// The human at the desk is per session. With no name, inbox.sh show gives the default human's
// inbox; with --name, it adds that person's: the beads assigned to their lowercase name and the ynm
// notes in human/<command>, with no roster entry. Nothing is written to the repository, and the
// desk's wake says the human can name themselves, never that they must register. Each case runs the
// real inbox.sh and wake.sh against a small Wheelhouse with bd and ynm stubbed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const inboxSh = join(plugin, "skills", "work-graph", "scripts", "inbox.sh");
const wakeSh = join(plugin, "skills", "wake", "scripts", "wake.sh");

const rosterText = JSON.stringify({
  seats: [
    { name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk with the human." },
    { name: "Gahan", group: "workers", command: "gahan", harness: "harnesses/gahan", mandate: "Build." },
  ],
  humans: [{ name: "Stakker", command: "stakker", pronouns: "they/them", default: true }],
});

const bead = (id, title) => ({ id, title, issue_type: "task", priority: 1, created_by: "gahan", dependent_count: 0, labels: ["inbox"] });

// bd ready --assignee <c> gives that human's bead; ynm recall --namespace human/<c> gives their note.
const bdStub = `#!/bin/sh
if [ "$1" = ready ]; then
  case " $* " in
    *" stakker "*) echo '${JSON.stringify([bead("hq-1", "Merge the changelog")])}'; exit 0 ;;
    *" david "*) echo '${JSON.stringify([bead("hq-2", "Decide the cache size")])}'; exit 0 ;;
  esac
fi
echo '[]'
`;
const ynmStub = `#!/bin/sh
case " $* " in
  *" human/david "*) echo '[{"memoryId":"M-DAVID","namespace":"human/david","tags":["inbox"],"content":"From gahan: the cache note"}]'; exit 0 ;;
  *" human/stakker "*) echo '[{"memoryId":"M-STAKKER","namespace":"human/stakker","tags":["inbox"],"content":"From gahan: the default note"}]'; exit 0 ;;
esac
echo '[]'
`;

function wheelhouse() {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-session-human-"));
  mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
  writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), rosterText);
  writeFileSync(join(dir, "AGENTS.md"), "**Mandate:** Talk with the human.\n");
  mkdirSync(join(dir, "bin"));
  for (const [name, body] of [["bd", bdStub], ["ynm", ynmStub]]) {
    writeFileSync(join(dir, "bin", name), body);
    chmodSync(join(dir, "bin", name), 0o755);
  }
  return dir;
}

const files = (dir) => readdirSync(dir, { recursive: true }).filter((f) => !f.startsWith("bin")).sort();

function run(dir, script, args) {
  return spawnSync("bash", [script, ...args], {
    cwd: dir,
    encoding: "utf8",
    env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, GIT_CONFIG_GLOBAL: "/dev/null" },
  });
}

function scenario(name, check) {
  const dir = wheelhouse();
  try {
    const before = files(dir);
    const roster = readFileSync(join(dir, "skills", "roster", "assets", "roster.json"), "utf8");
    const args = ["show", "--dir", ".", ...(name ? ["--name", name] : [])];
    const show = run(dir, inboxSh, args);
    check({ show, json: show.stdout ? JSON.parse(show.stdout) : null, dir });
    assert.deepEqual(files(dir), before, "nothing is written to the repository");
    assert.equal(readFileSync(join(dir, "skills", "roster", "assets", "roster.json"), "utf8"), roster);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("no name: show gives the default human's inbox, and nobody else's", () => {
  scenario(null, ({ show, json }) => {
    assert.equal(show.status, 0, show.stderr);
    assert.equal(json.you, null);
    assert.deepEqual(json.humans.map((h) => [h.command, h.role]), [["stakker", "anyone"]]);
    assert.equal(json.humans[0].beads[0].id, "hq-1");
    assert.equal(json.humans[0].notes[0].memoryId, "M-STAKKER");
    assert.equal("email" in json, false);
  });
});

test("--name David: show adds David's inbox for the session, with no roster entry", () => {
  scenario("David", ({ show, json }) => {
    assert.equal(show.status, 0, show.stderr);
    assert.deepEqual(json.you, { name: "David", command: "david" });
    assert.deepEqual(json.humans.map((h) => [h.name, h.command, h.role]), [
      ["David", "david", "you"],
      ["Stakker", "stakker", "anyone"],
    ]);
    const david = json.humans[0];
    assert.equal(david.beads[0].id, "hq-2");
    assert.equal(david.notes[0].memoryId, "M-DAVID");
    assert.equal(json.humans[1].beads[0].id, "hq-1");
  });
});

test("--name with capitals and spaces makes a lowercase command", () => {
  scenario("Jo Ann", ({ show, json }) => {
    assert.equal(show.status, 0, show.stderr);
    assert.equal(json.you.command, "joann");
    assert.equal(json.humans[0].name, "Jo Ann");
  });
});

test("--name the default human is the default human's inbox, shown once", () => {
  scenario("Stakker", ({ show, json }) => {
    assert.equal(show.status, 0, show.stderr);
    assert.equal(json.you, null);
    assert.equal(json.humans.length, 1);
  });
});

for (const [why, name, message] of [
  ["a seat's name", "Gahan", /is a seat, not a human/],
  ["a name with no letter or digit", "---", /can't make a command/],
]) {
  test(`--name refuses ${why}`, () => {
    scenario(name, ({ show }) => {
      assert.equal(show.status, 1, show.stdout);
      assert.match(show.stderr, message);
    });
  });
}

test("no email matching: git's user.email and WHEELHOUSE_HUMAN_EMAIL change nothing", () => {
  const dir = wheelhouse();
  try {
    const out = spawnSync("bash", [inboxSh, "show", "--dir", "."], {
      cwd: dir,
      encoding: "utf8",
      env: {
        ...process.env,
        PATH: `${join(dir, "bin")}:${process.env.PATH}`,
        WHEELHOUSE_HUMAN_EMAIL: "david@example.com",
        GIT_CONFIG_COUNT: "1",
        GIT_CONFIG_KEY_0: "user.email",
        GIT_CONFIG_VALUE_0: "david@example.com",
      },
    });
    assert.equal(out.status, 0, out.stderr);
    assert.deepEqual(JSON.parse(out.stdout).humans.map((h) => h.command), ["stakker"]);
    const arg = spawnSync("bash", [inboxSh, "show", "--dir", ".", "--email", "david@example.com"], { cwd: dir, encoding: "utf8" });
    assert.equal(arg.status, 1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("the desk's wake: no name shows Stakker's inbox and says the human can name themselves", () => {
  const dir = wheelhouse();
  try {
    const wake = run(dir, wakeSh, ["--seat", "hq", "--format", "text", "--no-sync"]);
    assert.equal(wake.status, 0, wake.stderr);
    assert.match(wake.stdout, /### Stakker \(anyone\)/);
    assert.match(wake.stdout, /Merge the changelog/);
    assert.doesNotMatch(wake.stdout, /Decide the cache size/);
    assert.match(wake.stdout, /name themselves for this session/);
    assert.doesNotMatch(wake.stdout, /register/i);
    assert.doesNotMatch(wake.stdout, /haven't said who you are/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
