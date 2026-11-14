// A bead in progress whose notes carry "PR: <url>" is marked in the wake, so a woken worker does not
// carry on with work that is only waiting on a review or a merge. Each case runs the real wake.sh
// with bd, gh and ynm stubbed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const wakeSrc = join(dirname(fileURLToPath(import.meta.url)), "..", "skills", "wake", "scripts", "wake.sh");
const memorySrc = join(dirname(fileURLToPath(import.meta.url)), "..", "skills", "work-graph", "scripts", "memory.sh");
const libSrc = join(dirname(fileURLToPath(import.meta.url)), "..", "skills", "work-graph", "scripts", "wheelhouse-lib.sh");
const roster = {
  seats: [{ name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build." }],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};
const inProgress = [
  { id: "b-1", title: "Waiting one", notes: "started\nPR: https://github.com/example/w/pull/1" },
  { id: "b-2", title: "Merged one", notes: "PR: https://github.com/example/w/pull/2" },
  { id: "b-3", title: "Unknown one", notes: "PR: https://github.com/example/w/pull/3" },
  { id: "b-4", title: "Plain one", notes: null },
];

function wake(ghBody) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-waiting-pr-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
    writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), "**Mandate:** Build.\n");
    mkdirSync(join(dir, "scripts"));
    writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
    for (const f of ["sync.sh", "render-wake.jq"]) writeFileSync(join(dir, "scripts", f), readFileSync(wakeSrc.replace(/wake\.sh$/, f)));
    writeFileSync(join(dir, "scripts", "memory.sh"), readFileSync(memorySrc));
    writeFileSync(join(dir, "scripts", "wheelhouse-lib.sh"), readFileSync(libSrc));
    mkdirSync(join(dir, "bin"));
    const bd = `#!/bin/sh\ncase " $* " in *" in_progress "*) cat <<'JSON'\n${JSON.stringify(inProgress)}\nJSON\n;; *) echo '[]' ;; esac\n`;
    for (const [name, body] of [["bd", bd], ["ynm", "#!/bin/sh\necho '[]'\n"], ["gh", ghBody]]) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    const r = spawnSync("bash", [join(dir, "scripts", "wake.sh"), "--seat", "hynde", "--format", "json", "--no-sync"], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "" },
    });
    assert.equal(r.status, 0, r.stderr);
    return JSON.parse(r.stdout).inProgress;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const gh = `#!/bin/sh
case "$*" in
  *pull/1*) echo OPEN ;;
  *pull/2*) echo MERGED ;;
  *) exit 1 ;;
esac
`;

test("a bead whose PR is open is marked waiting; merged and plain beads are not; unknown says so", () => {
  const got = wake(gh);
  assert.deepEqual(got, [
    "Waiting one (waiting on PR https://github.com/example/w/pull/1)",
    "Merged one",
    "Unknown one (PR noted: https://github.com/example/w/pull/3, state unknown)",
    "Plain one",
  ]);
});
