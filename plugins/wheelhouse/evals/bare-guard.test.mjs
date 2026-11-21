// A plain vendor session in a Wheelhouse repository is told it is not a seat; a session ynh
// launched (YNH_LABELS carries wheelhouse:<name>, which every seat's harness has) is told nothing;
// and the doctor warns about a vendor with no guard. Each case runs the real scripts.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const addHookSh = join(plugin, "skills", "create-wheelhouse", "scripts", "add-bare-guard-hook.sh");
const guardSrc = join(plugin, "skills", "create-wheelhouse", "scripts", "bare-guard.sh");
const checkSh = join(plugin, "skills", "doctor", "scripts", "check.sh");

function guard(vendor, labels) {
  const env = { ...process.env };
  delete env.YNH_LABELS;
  if (labels !== undefined) env.YNH_LABELS = labels;
  return spawnSync("bash", [guardSrc, "--vendor", vendor], { encoding: "utf8", env });
}

test("a plain claude or codex session is told in plain text that it is not a seat", () => {
  for (const vendor of ["claude", "codex"]) {
    const r = guard(vendor);
    assert.equal(r.status, 0);
    assert.match(r.stdout, /not a seat started through ynh/);
    assert.match(r.stdout, /do not claim or close beads as a seat/);
    assert.match(r.stdout, /do not write seat memory/);
  }
});

test("a plain cursor session is told through additional_context, as valid JSON", () => {
  const r = guard("cursor");
  assert.equal(r.status, 0);
  assert.match(JSON.parse(r.stdout).additional_context, /not a seat started through ynh/);
});

test("a session ynh launched, carrying wheelhouse:<name>, is told nothing", () => {
  for (const labels of ["wheelhouse:hq", "team:x,wheelhouse:hq", "wheelhouse:hq,team:x"]) {
    const r = guard("claude", labels);
    assert.equal(r.status, 0);
    assert.equal(r.stdout, "");
  }
});

test("other labels, or an empty one, do not make a session a seat", () => {
  for (const labels of ["", "team:x", "notwheelhouse:hq"]) {
    assert.match(guard("claude", labels).stdout, /not a seat/);
  }
});

test("a bad vendor prints nothing on stdout and still exits 0", () => {
  const r = guard("emacs");
  assert.equal(r.status, 0);
  assert.equal(r.stdout, "");
});

const hookFor = (vendor) => {
  // The commands create-wheelhouse writes: quoted and anchored for Claude Code and Codex.
  const cmd = {
    claude: 'bash "$CLAUDE_PROJECT_DIR/scripts/bare-guard.sh" --vendor claude',
    codex: 'bash "$(git rev-parse --show-toplevel)/scripts/bare-guard.sh" --vendor codex',
    cursor: 'bash "$(git rev-parse --show-toplevel)/scripts/bare-guard.sh" --vendor cursor',
  }[vendor];
  return vendor === "cursor"
    ? { version: 1, hooks: { sessionStart: [{ command: cmd }] } }
    : { hooks: { SessionStart: [{ hooks: [{ type: "command", command: cmd }] }] } };
};
const hookFile = { claude: ".claude/settings.json", codex: ".codex/hooks.json", cursor: ".cursor/hooks.json" };

function guardCheck({ vendor, guarded }) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-bare-"));
  try {
    const write = (path, body) => {
      mkdirSync(dirname(join(dir, path)), { recursive: true });
      writeFileSync(join(dir, path), typeof body === "string" ? body : JSON.stringify(body));
    };
    write(".agents/harness/plugin.json", { name: "hq", version: "0.1.0", default_vendor: vendor });
    write("skills/roster/assets/roster.json", { seats: [] });
    if (guarded) {
      mkdirSync(join(dir, "scripts"));
      copyFileSync(guardSrc, join(dir, "scripts", "bare-guard.sh"));
      chmodSync(join(dir, "scripts", "bare-guard.sh"), 0o755);
      write(hookFile[vendor], hookFor(vendor));
    }
    const r = spawnSync("bash", [checkSh, "--dir", dir], { encoding: "utf8" });
    return JSON.parse(r.stdout).checks.find((c) => c.name === "bare-session guard");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("the doctor warns about a vendor with no guard, naming it", () => {
  for (const vendor of ["claude", "codex", "cursor"]) {
    const c = guardCheck({ vendor, guarded: false });
    assert.equal(c.ok, false);
    assert.equal(c.level, "warn");
    assert.match(c.detail, new RegExp(`on: ${vendor}`));
    assert.match(c.fix, /bare-guard\.sh/);
  }
});

test("the doctor passes a vendor whose guard script and hook are there", () => {
  for (const vendor of ["claude", "codex", "cursor"]) {
    const c = guardCheck({ vendor, guarded: true });
    assert.equal(c.ok, true, c.detail);
  }
});

test("a vendor with no project-level session-start hook is named, not counted missing", () => {
  const c = guardCheck({ vendor: "opencode", guarded: false });
  assert.equal(c.ok, true);
  assert.match(c.detail, /opencode/);
});

// The hook-file merge: append-only, idempotent, everything else kept.
function withHookFile(vendor, existing, fn) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-hook-"));
  try {
    const path = join(dir, hookFile[vendor]);
    if (existing !== undefined) {
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, existing);
    }
    const run = () => spawnSync("bash", [addHookSh, "--dir", dir, "--vendor", vendor], { encoding: "utf8" });
    return fn({ run, read: () => readFileSync(path, "utf8"), path });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("the merge keeps another SessionStart hook, a permissions block and other events, and appends once", () => {
  const existing = {
    permissions: { allow: ["Bash(ls)"], deny: ["Read(.env)"] },
    hooks: {
      SessionStart: [{ matcher: "startup", hooks: [{ type: "command", command: "echo hi" }] }],
      Stop: [{ hooks: [{ type: "command", command: "echo bye" }] }],
    },
  };
  withHookFile("claude", JSON.stringify(existing), ({ run, read }) => {
    assert.match(run().stdout, /^added /);
    const once = JSON.parse(read());
    assert.deepEqual(once.permissions, existing.permissions);
    assert.deepEqual(once.hooks.Stop, existing.hooks.Stop);
    assert.equal(once.hooks.SessionStart.length, 2);
    assert.deepEqual(once.hooks.SessionStart[0], existing.hooks.SessionStart[0]);
    assert.match(once.hooks.SessionStart[1].hooks[0].command, /CLAUDE_PROJECT_DIR.*bare-guard\.sh.*--vendor claude/);
    const before = read();
    assert.match(run().stdout, /^already present /);
    assert.equal(read(), before);
  });
});

test("the merge creates a missing file for each vendor, in that vendor's shape, and a re-run adds nothing", () => {
  for (const vendor of ["claude", "codex", "cursor"]) {
    withHookFile(vendor, undefined, ({ run, read }) => {
      assert.equal(run().status, 0);
      assert.deepEqual(JSON.parse(read()), hookFor(vendor));
      const before = read();
      run();
      assert.equal(read(), before);
    });
  }
});

test("the merge keeps another Cursor hook and its version, and a doctor-visible entry results", () => {
  const existing = { version: 1, hooks: { sessionStart: [{ command: "echo hi" }], stop: [{ command: "echo bye" }] } };
  withHookFile("cursor", JSON.stringify(existing), ({ run, read }) => {
    run();
    const got = JSON.parse(read());
    assert.equal(got.version, 1);
    assert.deepEqual(got.hooks.stop, existing.hooks.stop);
    assert.deepEqual(got.hooks.sessionStart[0], existing.hooks.sessionStart[0]);
    assert.equal(got.hooks.sessionStart.length, 2);
  });
});

test("the merge refuses, changing nothing, a file that is not an object or has a non-array event", () => {
  for (const bad of ["[]", "not json", '{"hooks": {"SessionStart": {}}}']) {
    withHookFile("claude", bad, ({ run, read }) => {
      assert.equal(run().status, 1);
      assert.equal(read(), bad);
    });
  }
});

test("a merged file satisfies the doctor, and the hook command runs the guard from the repository root", () => {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-hook-"));
  try {
    mkdirSync(join(dir, "scripts"));
    copyFileSync(guardSrc, join(dir, "scripts", "bare-guard.sh"));
    spawnSync("git", ["init", "-q"], { cwd: dir });
    spawnSync("bash", [addHookSh, "--dir", dir, "--vendor", "codex"]);
    const cmd = JSON.parse(readFileSync(join(dir, ".codex/hooks.json"), "utf8")).hooks.SessionStart[0].hooks[0].command;
    mkdirSync(join(dir, "sub"));
    const env = { ...process.env };
    delete env.YNH_LABELS;
    const r = spawnSync("bash", ["-c", cmd], { cwd: join(dir, "sub"), encoding: "utf8", env });
    assert.match(r.stdout, /not a seat/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
