// A seat's session is launched under a name, <wheelhouse>-<command>, and the desk's is just the
// Wheelhouse's name, so one session can find another. add-seat's session-name.sh reads it from
// the roster. Each case runs the real script on a small roster.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const script = join(plugin, "skills", "add-seat", "scripts", "session-name.sh");
const seat = (command, group) => ({ name: command, group, command, harness: `harnesses/${command}`, mandate: "m" });

function name(roster, ...args) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-session-name-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    if (roster) writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    return spawnSync("bash", [script, "--dir", dir, ...args], { encoding: "utf8" });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const roster = { seats: [seat("hq", "desk"), seat("okafor", "workers"), seat("gore", "crew")] };

test("the desk is named for the Wheelhouse, every other seat <wheelhouse>-<command>", () => {
  assert.equal(name(roster, "--seat", "hq").stdout.trim(), "hq");
  assert.equal(name(roster, "--seat", "okafor").stdout.trim(), "hq-okafor");
  assert.equal(name(roster, "--seat", "gore").stdout.trim(), "hq-gore");
});

test("--format flag gives the launcher flag, with an equals sign", () => {
  assert.equal(name(roster, "--seat", "okafor", "--format", "flag").stdout.trim(), "--name=hq-okafor");
});

test("a seat that is not in the roster, or a roster with no desk, exits 4", () => {
  assert.equal(name(roster, "--seat", "nobody").status, 4);
  assert.equal(name({ seats: [seat("okafor", "workers")] }, "--seat", "okafor").status, 4);
});

test("no roster exits 2 and no seat exits 1", () => {
  assert.equal(name(null, "--seat", "okafor").status, 2);
  assert.equal(name(roster).status, 1);
});
