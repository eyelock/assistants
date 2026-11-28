// The harness template in the add-seat skill includes the desk ("git": "../..") with "hooks": false,
// as every seat's manifest does: the desk's hooks wake the desk, and a seat that leaves them on prints
// "included harness ../.. declares hooks ... that are not active" on every launch (assistants #347).
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const skill = readFileSync(join(plugin, "skills", "add-seat", "SKILL.md"), "utf8");

// The plugin.json block under "## 3. Write the harness".
const section = skill.slice(skill.indexOf("## 3. Write the harness"));
const template = JSON.parse(/```json\n([\s\S]*?)\n```/.exec(section)[1]);

test("the template's include of the desk carries hooks: false", () => {
  const desk = template.includes.filter((i) => i.git === "../..");
  assert.ok(desk.length > 0, "the template includes the desk");
  for (const i of desk) assert.equal(i.hooks, false, JSON.stringify(i));
});

test("the template's notes say why the desk's hooks stay off", () => {
  assert.match(section, /"hooks": false.*`\.\.\/\.\.`|`"hooks": false` on it/s);
  assert.match(section, /declares hooks/);
});

test("the skill's evals expect a new seat's ../.. include with hooks false", () => {
  const evals = readFileSync(join(plugin, "skills", "add-seat", "evals", "evals.json"), "utf8");
  assert.match(evals, /git \.\.\/\.\. picking skills\/roster, with hooks false/);
});
