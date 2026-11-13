// The wake block ends with the line that sends a seat to the comms skill before it talks to the
// human, for the desk and for a worker alike. Runs the real wake.sh with bd, gh and ynm stubbed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const src = (...p) => join(here, "..", "skills", ...p);
const roster = {
  seats: [
    { name: "Ynw", group: "desk", command: "ynw", harness: ".", mandate: "Talk." },
    { name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build." },
  ],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};
const LINE =
  "Before you talk to the human, load the comms skill: every decision goes through your question tool, and every report ends with Status, Work in progress and Your action.";

function wake(seat) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-comms-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
    writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), "**Mandate:** Build.\n");
    mkdirSync(join(dir, "scripts"));
    for (const [from, to] of [[src("wake", "scripts", "wake.sh"), "wake.sh"], [src("work-graph", "scripts", "memory.sh"), "memory.sh"], [src("work-graph", "scripts", "wheelhouse-lib.sh"), "wheelhouse-lib.sh"], [src("work-graph", "scripts", "inbox.sh"), "inbox.sh"]]) {
      writeFileSync(join(dir, "scripts", to), readFileSync(from));
    }
    mkdirSync(join(dir, "bin"));
    for (const [name, body] of Object.entries({ bd: "#!/bin/sh\necho '[]'\n", ynm: "#!/bin/sh\necho '[]'\n", gh: "#!/bin/sh\nexit 1\n" })) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    const r = spawnSync("bash", [join(dir, "scripts", "wake.sh"), "--seat", seat, "--format", "text", "--dir", dir], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}` },
    });
    assert.equal(r.status, 0, r.stderr);
    return r.stdout;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

for (const seat of ["ynw", "hynde"]) {
  test(`the ${seat} wake block ends with the comms line`, () => {
    const out = wake(seat).trimEnd();
    assert.ok(out.endsWith(LINE), `block does not end with the comms line:\n${out.slice(-300)}`);
    assert.equal(out.split(LINE).length - 1, 1);
  });
}
