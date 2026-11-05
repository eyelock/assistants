// A seat the desk wakes as a subagent has no session-start hook, so it runs the Wheelhouse's own
// scripts/wake.sh itself. The script takes the seat as --seat <name> or bare, from any directory
// with --dir, and stops with usage, listing the roster's seats, when it can't tell which seat it
// is. Each case runs the real wake.sh against a small Wheelhouse with bd and ynm stubbed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const wakeSrc = join(plugin, "skills", "wake", "scripts", "wake.sh");

const roster = {
  seats: [
    { name: "Hq", group: "desk", command: "hq", harness: ".", mandate: "Talk with the human." },
    { name: "Hynde", group: "workers", command: "hynde", harness: "harnesses/hynde", mandate: "Build." },
  ],
  humans: [{ name: "Rook", command: "rook", pronouns: "they/them", default: true }],
};

// ynm: recall answers a seat's identity from its own namespace; anything else is empty.
const ynmStub = `#!/bin/sh
if [ "$1" = recall ]; then
  case " $* " in
    *" seat/hynde "*" identity "*) echo '[{"memoryId":"M1","content":"I am Hynde, a careful builder."}]'; exit 0 ;;
  esac
fi
echo '[]'
`;

function wheelhouse() {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-args-"));
  mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
  writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
  mkdirSync(join(dir, "harnesses", "hynde"), { recursive: true });
  writeFileSync(join(dir, "harnesses", "hynde", "AGENTS.md"), "**Mandate:** Build one bead at a time.\n");
  mkdirSync(join(dir, "scripts"));
  writeFileSync(join(dir, "scripts", "wake.sh"), readFileSync(wakeSrc));
  mkdirSync(join(dir, "bin"));
  for (const [name, body] of [["bd", "#!/bin/sh\necho '[]'\n"], ["ynm", ynmStub]]) {
    writeFileSync(join(dir, "bin", name), body);
    chmodSync(join(dir, "bin", name), 0o755);
  }
  return dir;
}

function wake(args, { cwd, env = {} } = {}) {
  const dir = wheelhouse();
  try {
    const out = spawnSync("bash", [join(dir, "scripts", "wake.sh"), ...args.map((a) => (a === "<dir>" ? dir : a)), "--no-sync"], {
      cwd: cwd === "elsewhere" ? tmpdir() : dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BEADS_ACTOR: "", ...env },
    });
    return out;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("--seat <command> from the Wheelhouse root gives the seat's identity block", () => {
  const r = wake(["--seat", "hynde", "--format", "text"]);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /# Waking: hynde/);
  assert.match(r.stdout, /I am Hynde, a careful builder\./);
  assert.match(r.stdout, /Build one bead at a time\./);
});

test("the bare seat name does the same as --seat", () => {
  const r = wake(["hynde", "--format", "text"]);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /I am Hynde, a careful builder\./);
});

test("a subagent started elsewhere wakes with the full path and --dir", () => {
  const r = wake(["hynde", "--dir", "<dir>", "--format", "text"], { cwd: "elsewhere" });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /I am Hynde, a careful builder\./);
});

test("the same seat given both ways is fine; two different seats are refused with usage", () => {
  assert.equal(wake(["--seat", "hynde", "hynde", "--format", "text"]).status, 0);
  const r = wake(["--seat", "hynde", "hq"]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /two different seats named/);
  assert.match(r.stderr, /Usage: wake\.sh/);
});

test("two bare names are refused with usage", () => {
  const r = wake(["hynde", "hq"]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /more than one seat named/);
  assert.match(r.stderr, /Usage: wake\.sh/);
});

test("no seat at all stops with usage and lists the roster's seats", () => {
  const r = wake(["--format", "text"]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /no seat:.*hq, hynde/);
  assert.match(r.stderr, /Usage: wake\.sh/);
  assert.equal(r.stdout, "");
});

test("BEADS_ACTOR still names the seat when none is given", () => {
  const r = wake(["--format", "text"], { env: { BEADS_ACTOR: "hynde" } });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /I am Hynde, a careful builder\./);
});

test("a name that is not a seat is refused", () => {
  const r = wake(["nobody"]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /nobody is not a seat in the roster/);
});

test("an unknown flag is still refused with usage", () => {
  const r = wake(["--sead", "hynde"]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /unknown argument: --sead/);
});
