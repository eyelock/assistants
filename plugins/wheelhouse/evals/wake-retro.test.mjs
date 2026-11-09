// A seat's own retro bead (labelled retro:<seat>) is shown under "Your retro", apart from "Waiting
// for you", and unassigned beads labelled retro are left out of the ready list. Each case runs the
// real wake.sh with bd, gh and ynm stubbed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const wakeSrc = join(dirname(fileURLToPath(import.meta.url)), "..", "skills", "wake", "scripts", "wake.sh");
const roster = {
  seats: [{ name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build." }],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};
const inProgress = [
  { id: "w-1", title: "Real work", labels: [] },
  { id: "r-1", title: "Hynde retro", labels: ["retro", "retro:hynde"] },
];
const assigned = [
  { id: "w-2", title: "Assigned work", labels: [], issue_type: "task" },
  { id: "r-2", title: "Hynde retro round 2", labels: ["retro", "retro:hynde"], issue_type: "task" },
  { id: "r-3", title: "Review Hynde's retro", labels: ["retro"], issue_type: "task" },
];
const unassigned = [
  { id: "u-1", title: "Free work", labels: [], priority: 2, issue_type: "task" },
  { id: "r-4", title: "Someone's retro", labels: ["retro", "retro:other"], priority: 0, issue_type: "task" },
];

function wake(format) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-retro-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
    writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), "**Mandate:** Build.\n");
    mkdirSync(join(dir, "scripts"));
    writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
    mkdirSync(join(dir, "bin"));
    const bd = `#!/bin/sh
case " $* " in
  *" in_progress "*) cat <<'JSON'
${JSON.stringify(inProgress)}
JSON
;;
  *" --unassigned "*) cat <<'JSON'
${JSON.stringify(unassigned)}
JSON
;;
  *" ready "*) cat <<'JSON'
${JSON.stringify(assigned)}
JSON
;;
  *) echo '[]' ;;
esac
`;
    for (const [name, body] of [["bd", bd], ["ynm", "#!/bin/sh\necho '[]'\n"], ["gh", "#!/bin/sh\nexit 1\n"]]) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    const r = spawnSync("bash", [join(dir, "scripts", "wake.sh"), "--seat", "hynde", "--format", format, "--no-sync"], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "" },
    });
    assert.equal(r.status, 0, r.stderr);
    return r.stdout;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("the seat's own retro beads are kept apart, other retro beads stay work, unassigned retro beads are skipped", () => {
  const got = JSON.parse(wake("json"));
  assert.deepEqual(got.inProgress, ["Real work"]);
  assert.deepEqual(got.assigned, ["Assigned work", "Review Hynde's retro"]);
  assert.deepEqual(got.retro, ["Hynde retro", "Hynde retro round 2"]);
  assert.deepEqual(got.unassignedReady, ["Free work"]);
});

test("the text block shows Your retro after Waiting for you, with the rule", () => {
  const text = wake("text");
  const waiting = text.indexOf("## Waiting for you");
  const retro = text.indexOf("## Your retro");
  assert.ok(waiting >= 0 && retro > waiting, text);
  assert.match(text.slice(retro), /- Hynde retro\n- Hynde retro round 2/);
  assert.match(text.slice(retro), /never comes before the bead you were woken or asked for/);
  assert.ok(!text.slice(waiting, retro).includes("Hynde retro"), "own retro leaked into Waiting for you");
});
