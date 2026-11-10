// tracker-generic.sh is open-pr.sh's fallback adapter for a tracker kind with no adapter of its own.
// Each case runs the real script: it names the item in the PR body, sets no release flag, and
// refuses (exit 3) to read a release or a state it cannot know.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const script = join(plugin, "skills", "work-graph", "scripts", "tracker-generic.sh");
const run = (...args) => spawnSync("bash", [script, ...args], { encoding: "utf8" });

test("closing names the item, saying whether it is the last open bead on it", () => {
  const last = run("closing", "JIRA-12", "last", "eyelock/ynh");
  assert.equal(last.status, 0);
  assert.equal(last.stdout, "Tracker item (this is the last open bead on it): JIRA-12\n");
  const more = run("closing", "JIRA-12", "more", "eyelock/ynh");
  assert.equal(more.status, 0);
  assert.equal(more.stdout, "Tracker item (part of it): JIRA-12\n");
});

test("closing with the wrong number of arguments is a usage error", () => {
  const r = run("closing", "JIRA-12");
  assert.equal(r.status, 1);
  assert.match(r.stderr, /usage: tracker-generic\.sh closing/);
});

test("canon prints the reference unchanged", () => {
  const r = run("canon", "JIRA-12");
  assert.equal(r.status, 0);
  assert.equal(r.stdout, "JIRA-12\n");
});

test("pr-flags sets no release flag", () => {
  const r = run("pr-flags", "v1.0");
  assert.equal(r.status, 0);
  assert.equal(r.stdout, "");
});

for (const verb of ["release", "state"]) {
  test(`${verb} is a fault (exit 3) that points at a tracker-<kind>.sh`, () => {
    const r = run(verb, "JIRA-12");
    assert.equal(r.status, 3);
    assert.equal(r.stdout, "");
    assert.match(r.stderr, new RegExp(`cannot read a ${verb}: add tracker-<kind>\\.sh`));
  });
}

test("an unknown verb, or none, is a usage error", () => {
  for (const args of [["bogus"], []]) {
    const r = run(...args);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /usage: tracker-generic\.sh/);
  }
});
