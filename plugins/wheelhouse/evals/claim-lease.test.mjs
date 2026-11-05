// A claim's lease: what bd does with it, and that work-graph tells seats to heartbeat. The cases run
// the real `bd` in a scratch graph (skipped when bd is not installed). A lapse itself takes bd's
// five-minute lease to reproduce, so it is not run here: the skill records what it showed (a lapsed
// lease frees nothing until `bd reclaim`, which then refuses the old holder's heartbeat).
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const skill = readFileSync(join(plugin, "skills", "work-graph", "SKILL.md"), "utf8");
const hasBd = spawnSync("bd", ["--version"]).status === 0;

test("work-graph tells seats to heartbeat, and what a lapse does", () => {
  const section = skill.split("## Keeping your claim")[1]?.split("\n## ")[0] ?? "";
  assert.match(section, /bd heartbeat <id>/);
  assert.match(section, /five minutes/);
  assert.match(section, /bd reclaim/);
  assert.match(section, /Never run `bd reclaim` or `bd update --force` on another seat's bead/);
  assert.match(skill, /\(#keeping-your-claim\)/, "What's next points at the rule");
});

test("only the holder heartbeats; a live claim refuses another seat", { skip: !hasBd }, () => {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-lease-"));
  const bd = (...args) => spawnSync("bd", args, { cwd: dir, encoding: "utf8" });
  try {
    spawnSync("git", ["init", "-q", "-b", "main", "."], { cwd: dir });
    assert.equal(bd("init", "--skip-agents", "--prefix", "ls").status, 0);
    const id = /ls-[a-z0-9]+/.exec(bd("create", "probe", "-p", "2", "--actor", "ynw").stdout)?.[0];
    assert.ok(id, "bead created");
    assert.equal(bd("update", id, "--claim", "--actor", "alice").status, 0);
    assert.match(bd("show", id).stdout, /Lease: expires in/);
    assert.equal(bd("heartbeat", id, "--actor", "alice").status, 0, "the holder refreshes");
    assert.notEqual(bd("heartbeat", id, "--actor", "bob").status, 0, "another seat cannot");
    const refused = bd("update", id, "--claim", "--actor", "bob");
    assert.notEqual(refused.status, 0);
    assert.match(refused.stdout + refused.stderr, /already claimed by alice/);
    assert.match(bd("reclaim").stdout + bd("reclaim").stderr, /No stale leases/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
