// A seat's wake shows the whole Mandate paragraph from its charter, not only the first line of it.
// Each case runs the real wake.sh against a small Wheelhouse with bd and ynm stubbed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const wakeSrc = join(plugin, "skills", "wake", "scripts", "wake.sh");
const memorySrc = join(plugin, "skills", "work-graph", "scripts", "memory.sh");

const roster = {
  seats: [{ name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Roster fallback." }],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};

function mandateFor(charter) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-mandate-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
    writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), charter);
    mkdirSync(join(dir, "scripts"));
    writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
    for (const f of ["sync.sh", "render-wake.jq"]) writeFileSync(join(dir, "scripts", f), readFileSync(wakeSrc.replace(/wake\.sh$/, f)));
    writeFileSync(join(dir, "scripts", "memory.sh"), readFileSync(memorySrc));
    writeFileSync(join(dir, "scripts", "wheelhouse-lib.sh"), readFileSync(join(plugin, "skills", "work-graph", "scripts", "wheelhouse-lib.sh")));
    mkdirSync(join(dir, "bin"));
    for (const [name, body] of [
      ["bd", "#!/bin/sh\necho '[]'\n"],
      ["ynm", "#!/bin/sh\necho '[]'\n"],
    ]) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    const r = spawnSync("bash", [join(dir, "scripts", "wake.sh"), "--seat", "hynde", "--format", "json", "--no-sync"], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "" },
    });
    assert.equal(r.status, 0, r.stderr);
    return JSON.parse(r.stdout).mandate;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("a Mandate wrapped over several lines is read whole, up to the blank line", () => {
  const m = mandateFor("# Hynde\n\n**Mandate:** Build one bead at a time: first one\n  assigned to you, else a ready one.\nTake only labelled beads.\n\n**You may:**\n- x\n");
  assert.equal(m, "Build one bead at a time: first one assigned to you, else a ready one. Take only labelled beads.");
});

test("a one-line Mandate is unchanged", () => {
  assert.equal(mandateFor("**Mandate:** Build.\n\n**You may:**\n"), "Build.");
});

test("a Mandate at the end of the file with no blank line after it is read whole", () => {
  assert.equal(mandateFor("**Mandate:** Build\nmore."), "Build more.");
});

test("a charter with no Mandate falls back to the roster's", () => {
  assert.equal(mandateFor("# Hynde\n"), "Roster fallback.");
});
