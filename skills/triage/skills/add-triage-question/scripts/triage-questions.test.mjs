import assert from "node:assert/strict";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { check, findRoot, promptFor, sync } from "./triage-questions.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const LIST = join("skills", "triage", "skills", "add-triage-question", "assets", "questions.json");

test("the real harnesses match the common list", () => {
  assert.deepEqual(check(findRoot(here)), []);
});

function fixture(listEdit = (list) => list, focuses = {}) {
  const root = mkdtempSync(join(tmpdir(), "triage-questions-"));
  const real = findRoot(here);
  mkdirSync(dirname(join(root, LIST)), { recursive: true });
  const list = {
    platforms: { alpha: { name: "Alpha", at: "on Alpha" } },
    questions: [
      { id: "ask-one", skills: ["waiting-on-me"], ask: "find one {at}.", on: ["alpha"] },
    ],
  };
  writeFileSync(join(root, LIST), JSON.stringify(listEdit(list)));
  cpSync(
    join(real, "skills/triage/skills/waiting-on-me"),
    join(root, "skills/triage/skills/waiting-on-me"),
    { recursive: true },
  );
  mkdirSync(join(root, "ynh/alpha/.agents/harness"), { recursive: true });
  writeFileSync(
    join(root, "ynh/alpha/.agents/harness/plugin.json"),
    JSON.stringify({ name: "alpha", focuses }),
  );
  mkdirSync(join(root, "skills/platforms/skills/alpha/references"), { recursive: true });
  writeFileSync(join(root, "skills/platforms/skills/alpha/references/triage.md"), "ask-one: look here\n");
  return root;
}

test("a missing focus is reported, and sync writes it", () => {
  const root = fixture();
  try {
    assert.match(check(root).join("\n"), /ynh\/alpha has no ask-one focus/);
    assert.deepEqual(sync(root), ["alpha"]);
    assert.deepEqual(check(root), []);
    assert.deepEqual(sync(root), []);
    const manifest = JSON.parse(readFileSync(join(root, "ynh/alpha/.agents/harness/plugin.json"), "utf8"));
    assert.equal(manifest.focuses["ask-one"].prompt, "Use the waiting-on-me skill to find one on Alpha.");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("sync keeps a focus's own keys and focuses the list does not own", () => {
  const root = fixture((l) => l, { "ask-one": { profile: "deep", prompt: "old" }, all: { prompt: "x" } });
  try {
    sync(root);
    const f = JSON.parse(readFileSync(join(root, "ynh/alpha/.agents/harness/plugin.json"), "utf8")).focuses;
    assert.equal(f["ask-one"].profile, "deep");
    assert.equal(f.all.prompt, "x");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a platform must sit in exactly one bucket", () => {
  const root = fixture((l) => {
    l.questions[0].todo = ["alpha"];
    return l;
  });
  try {
    assert.match(check(root).join("\n"), /exactly one of on, not_on or todo \(it is in 2\)/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("not_on needs a reason, and a todo platform must not have the focus", () => {
  const root = fixture(
    (l) => {
      l.questions[0].on = [];
      l.questions[0].not_on = { alpha: "no" };
      return l;
    },
    { "ask-one": { prompt: "x" } },
  );
  try {
    const problems = check(root).join("\n");
    assert.match(problems, /not_on alpha needs a reason/);
    assert.match(problems, /has a ask-one focus but the list does not have it on/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a harness that includes the triage package must be listed", () => {
  const root = fixture();
  try {
    mkdirSync(join(root, "ynh/beta/.agents/harness"), { recursive: true });
    writeFileSync(
      join(root, "ynh/beta/.agents/harness/plugin.json"),
      JSON.stringify({ name: "beta", includes: [{ path: "skills/triage" }], focuses: {} }),
    );
    assert.match(check(root).join("\n"), /ynh\/beta includes skills\/triage but is not in platforms/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a prompt names one skill in the singular and several in the plural", () => {
  const platform = { name: "Alpha", at: "on Alpha" };
  assert.equal(promptFor({ skills: ["a"], ask: "do it {at}." }, platform), "Use the a skill to do it on Alpha.");
  assert.equal(promptFor({ skills: ["a", "b"], ask: "do it {at}." }, platform), "Use the a and b skills to do it on Alpha.");
});
