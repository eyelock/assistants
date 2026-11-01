// The refresh skill maps a git diff, after a pull, to what it needs: ynh installs, a trust
// instruction for the human, restarts, or nothing. Each case builds a small Wheelhouse in git, makes
// a commit, and runs the real refresh.sh over the diff, with ynh, ynm and the doctor stubbed on PATH
// (the stubs log every call to $STUB_LOG, so a test can see what was run and what was not).
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const refreshSh = join(plugin, "skills", "refresh", "scripts", "refresh.sh");

// ynh: logs the call; ls answers from $YNH_LS; install fails for a path named in $YNH_FAIL.
const ynhStub = `#!/bin/sh
printf 'ynh %s\\n' "$*" >> "$STUB_LOG"
case "$1" in
  ls) cat "$YNH_LS" ;;
  install) [ "$2" = "$YNH_FAIL" ] && { echo "install failed" >&2; exit 1; }; echo "installed $2" ;;
  update) echo "updated $2" ;;
  trust) [ "$2" = ls ] && { cat "$YNH_TRUST"; exit 0; }; echo "ynh trust accept and show must never be run" >&2; exit 1 ;;
esac
`;
// ynm: recall prints a pinned identity for every seat except those in $UNBORN.
const ynmStub = `#!/bin/sh
printf 'ynm %s\\n' "$*" >> "$STUB_LOG"
ns=""; prev=""
for a in "$@"; do [ "$prev" = --namespace ] && ns="$a"; prev="$a"; done
seat=\${ns#seat/}
case " $UNBORN " in *" $seat "*) echo '[]' ;; *) printf '[{"namespace":"%s","pinned":true}]\\n' "$ns" ;; esac
`;
const doctorStub = `#!/bin/sh
echo '{"ok":true,"dir":".","checks":[{"name":"stub","ok":true,"level":"info","detail":"fine","fix":null}]}'
`;

const SEATS = [
  ["hq", "desk"],
  ["eno", "crew"],
  ["wick", "workers"],
  ["dree", "standing"],
];
const manifest = (name, over = {}) => ({
  name,
  version: "0.1.0",
  includes: [
    { git: "https://example.com/assistants", path: "plugins/wheelhouse" },
    { git: "../..", pick: ["skills/roster"] },
  ],
  ...over,
});

function write(root, rel, content) {
  mkdirSync(dirname(join(root, rel)), { recursive: true });
  writeFileSync(join(root, rel), typeof content === "string" ? content : `${JSON.stringify(content, null, 2)}\n`);
}
const git = (cwd, ...args) => spawnSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", ...args], { cwd, encoding: "utf8" });

function ynhLs(names, installedRef = "aaa", availableRef = "aaa") {
  return {
    harnesses: names.map((name) => ({
      id: `local/${name}`,
      name,
      includes: [{ git: "https://example.com/assistants", path: "plugins/wheelhouse", ref_installed: installedRef, ref_available: availableRef, is_pinned: false }],
    })),
  };
}

// ynh trust ls --format json: every seat accepted unless named in `states` (seat -> state).
function trustLs(states = {}) {
  return SEATS.map(([c]) => ({ harness: `local/${c}`, state: states[c] ?? "accepted" }));
}

function wheelhouse() {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-refresh-"));
  const wh = join(dir, "wh");
  mkdirSync(join(dir, "bin"));
  for (const [name, body] of [["ynh", ynhStub], ["ynm", ynmStub], ["doctor.sh", doctorStub]]) {
    writeFileSync(join(dir, "bin", name), body);
    chmodSync(join(dir, "bin", name), 0o755);
  }
  git(dir, "init", "-q", "-b", "main", wh);
  write(wh, "AGENTS.md", "# hq\n");
  write(wh, ".agents/harness/plugin.json", manifest("hq", { workspace: ["../api"] }));
  write(wh, "skills/roster/SKILL.md", "roster\n");
  write(wh, "skills/roster/assets/roster.json", {
    seats: SEATS.map(([command, group]) => ({ name: command, command, group, harness: command === "hq" ? "." : `harnesses/${command}` })),
  });
  write(wh, "skills/extra/SKILL.md", "extra\n");
  write(wh, "scripts/wake.sh", "#!/bin/sh\n# v1\n");
  write(wh, "docs/notes.md", "notes\n");
  for (const [command] of SEATS.slice(1)) {
    write(wh, `harnesses/${command}/AGENTS.md`, `# ${command}\n`);
    write(wh, `harnesses/${command}/.agents/harness/plugin.json`, manifest(command));
    write(wh, `harnesses/${command}/.agents/harness/pinned-skills.md`, "pins\n");
  }
  // dree's include of ../.. picks skills/extra as well.
  write(wh, "harnesses/dree/.agents/harness/plugin.json", manifest("dree", { includes: [{ git: "../..", pick: ["skills/roster", "skills/extra"] }] }));
  git(wh, "add", "-A");
  git(wh, "commit", "-qm", "base");
  writeFileSync(join(dir, "ls.json"), JSON.stringify(ynhLs(SEATS.map(([c]) => c))));
  writeFileSync(join(dir, "trust.json"), JSON.stringify(trustLs()));
  const env = (extra = {}) => ({
    ...process.env,
    PATH: `${join(dir, "bin")}:${process.env.PATH}`,
    STUB_LOG: join(dir, "stub.log"),
    YNH_LS: join(dir, "ls.json"),
    YNH_TRUST: join(dir, "trust.json"),
    YNH_FAIL: "",
    UNBORN: "",
    YNH_HOME: join(dir, "ynhhome"),
    ...extra,
  });
  return {
    dir,
    wh,
    // Commit the changes `fn` makes, then run refresh over base..new.
    change(fn) {
      fn((rel, content) => write(wh, rel, content));
      git(wh, "add", "-A");
      git(wh, "commit", "-qm", "change");
    },
    run(args = [], extra = {}) {
      const out = spawnSync("bash", [refreshSh, "--dir", wh, "--doctor", join(dir, "bin", "doctor.sh"), ...args], { encoding: "utf8", env: env(extra) });
      let json = null;
      try {
        json = JSON.parse(out.stdout);
      } catch {}
      return { ...out, json };
    },
    log: () => (existsSync(join(dir, "stub.log")) ? readFileSync(join(dir, "stub.log"), "utf8") : ""),
    done: () => rmSync(dir, { recursive: true, force: true }),
  };
}

const diff = ["HEAD~1..HEAD"];

test("a changed seat is reinstalled alone, and a pinned-skills.md change is nothing", () => {
  const w = wheelhouse();
  try {
    w.change((put) => {
      put("harnesses/wick/AGENTS.md", "# wick, changed\n");
      put("harnesses/eno/.agents/harness/pinned-skills.md", "new pins\n");
      put("docs/notes.md", "changed notes\n");
    });
    const r = w.run(diff);
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(r.json.install, ["ynh install harnesses/wick"]);
    assert.deepEqual(r.json.restart, ["wick"]);
    assert.deepEqual(r.json.trust, []);
    assert.ok(r.json.ignored.includes("docs/notes.md"));
    assert.ok(r.json.ignored.includes("harnesses/eno/.agents/harness/pinned-skills.md"));
    assert.match(w.log(), /^ynh install harnesses\/wick$/m);
    assert.doesNotMatch(w.log(), /install harnesses\/eno/);
    assert.equal(r.json.doctor.ok, true);
  } finally {
    w.done();
  }
});

test("the root AGENTS.md, root plugin.json and the roster reinstall the desk and every seat", () => {
  for (const change of [
    (put) => put("AGENTS.md", "# hq, changed\n"),
    (put) => put(".agents/harness/plugin.json", manifest("hq", { workspace: ["../api"], description: "changed" })),
    (put) => put("skills/roster/assets/extra.md", "roster change\n"),
  ]) {
    const w = wheelhouse();
    try {
      w.change(change);
      const r = w.run(diff);
      assert.equal(r.status, 0, r.stderr);
      assert.deepEqual(r.json.install, ["ynh install .", "ynh install harnesses/dree", "ynh install harnesses/eno", "ynh install harnesses/wick"]);
      assert.deepEqual(r.json.restart, ["dree", "eno", "hq", "wick"]);
      assert.deepEqual(r.json.trust, []);
    } finally {
      w.done();
    }
  }
});

test("another desk skill reinstalls the desk and only the seats whose ../.. include picks it", () => {
  const w = wheelhouse();
  try {
    w.change((put) => put("skills/extra/SKILL.md", "extra, changed\n"));
    const r = w.run(diff);
    assert.deepEqual(r.json.install, ["ynh install .", "ynh install harnesses/dree"]);
    assert.deepEqual(r.json.restart, ["dree", "hq"]);
  } finally {
    w.done();
  }
});

test("a workspace folder added to a harness prints a trust instruction and never runs it", () => {
  const w = wheelhouse();
  try {
    w.change((put) => {
      put("harnesses/wick/.agents/harness/plugin.json", manifest("wick", { workspace: ["../../api"] }));
      put(".agents/harness/plugin.json", manifest("hq", { workspace: ["../api", "../web"] }));
      // An unchanged workspace is not a trust change.
      put("harnesses/eno/.agents/harness/plugin.json", manifest("eno", { description: "just words" }));
    });
    const r = w.run(diff);
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(r.json.trust, ["ynh trust accept local/hq", "ynh trust accept local/wick"]);
    assert.doesNotMatch(w.log(), /ynh trust (accept|show)/);
    assert.ok(r.json.install.includes("ynh install harnesses/eno"));
  } finally {
    w.done();
  }
});

test("a hook, MCP server, sensor or launch focus change prints a trust instruction, and so does a removed workspace folder", () => {
  const w = wheelhouse();
  try {
    w.change((put) => {
      put("harnesses/wick/.agents/harness/plugin.json", manifest("wick", { hooks: { before_tool: [{ command: "echo hi" }] } }));
      put("harnesses/eno/.agents/harness/plugin.json", manifest("eno", { mcp_servers: { x: { command: "x" } }, launch_focus: "wake" }));
      put("harnesses/dree/.agents/harness/plugin.json", manifest("dree", { sensors: { s: { command: "true" } } }));
      put(".agents/harness/plugin.json", manifest("hq", { workspace: [] }));
    });
    const r = w.run(diff);
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(r.json.trust, ["ynh trust accept local/dree", "ynh trust accept local/eno", "ynh trust accept local/hq", "ynh trust accept local/wick"]);
    assert.doesNotMatch(w.log(), /ynh trust (accept|show)/);
  } finally {
    w.done();
  }
});

test("a hook in a profile, a changed launch focus prompt and a delegates_to focus change each print a trust instruction; delegates and unrelated profile text do not", () => {
  const base = {
    launch_focus: "wake",
    focuses: { wake: { prompt: "wake up" } },
    profiles: { ci: { hooks: { before_tool: [{ command: "echo a" }] }, description: "words" } },
    delegates_to: [{ git: "https://example.com/d", focus: "review" }],
  };
  const w = wheelhouse();
  try {
    w.change((put) => {
      for (const c of ["eno", "wick", "dree"]) put(`harnesses/${c}/.agents/harness/plugin.json`, manifest(c, base));
    });
    // The first change only gave eno, wick and dree these fields (dree is new in no sense: it existed).
    w.change((put) => {
      put("harnesses/eno/.agents/harness/plugin.json", manifest("eno", { ...base, profiles: { ci: { hooks: { before_tool: [{ command: "echo b" }] } } } }));
      put("harnesses/wick/.agents/harness/plugin.json", manifest("wick", { ...base, focuses: { wake: { prompt: "wake up, now" } } }));
      put("harnesses/dree/.agents/harness/plugin.json", manifest("dree", { ...base, delegates_to: [{ git: "https://example.com/d", focus: "audit" }] }));
      // Only profile text outside what the digest covers changes: not a trust change.
      put(".agents/harness/plugin.json", manifest("hq", { workspace: ["../api"], profiles: { ci: { description: "other words" } } }));
    });
    const r = w.run(["HEAD~1..HEAD"]);
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(r.json.trust, ["ynh trust accept local/dree", "ynh trust accept local/eno", "ynh trust accept local/wick"]);
  } finally {
    w.done();
  }
});

test("a profile description change alone is not a trust change", () => {
  const w = wheelhouse();
  try {
    w.change((put) => put("harnesses/eno/.agents/harness/plugin.json", manifest("eno", { profiles: { ci: { description: "a" } } })));
    w.change((put) => put("harnesses/eno/.agents/harness/plugin.json", manifest("eno", { profiles: { ci: { description: "b" } } })));
    const r = w.run(["HEAD~1..HEAD"]);
    assert.deepEqual(r.json.trust, []);
  } finally {
    w.done();
  }
});

test("a seat ynh lists as unavailable is noted with its problems and what fixes it, and is not offered trust accept", () => {
  const w = wheelhouse();
  try {
    writeFileSync(join(w.dir, "trust.json"), JSON.stringify([...trustLs({ wick: "x" }).filter((t) => t.harness !== "local/wick"), { harness: "local/wick", state: "unavailable", problems: ["includes: not cached"] }]));
    w.change((put) => put("docs/notes.md", "more\n"));
    const r = w.run(diff);
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(r.json.trust, []);
    const n = r.json.notes.find((x) => x.includes("local/wick"));
    assert.match(n, /unavailable/);
    assert.match(n, /includes: not cached/);
    assert.match(n, /ynh update local\/wick/);
    assert.match(n, /trust accept does not fix/);
  } finally {
    w.done();
  }
});

test("a seat ynh reports changed or unreviewed after the installs gets a trust instruction, even when the diff shows no cause", () => {
  const w = wheelhouse();
  try {
    writeFileSync(join(w.dir, "trust.json"), JSON.stringify(trustLs({ eno: "changed", dree: "unreviewed", wick: "no-commands" })));
    w.change((put) => put("docs/notes.md", "more\n"));
    const r = w.run(diff);
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(r.json.trust, ["ynh trust accept local/dree", "ynh trust accept local/eno"]);
    assert.match(w.log(), /^ynh trust ls --format json$/m);
    assert.doesNotMatch(w.log(), /ynh trust (accept|show)/);
  } finally {
    w.done();
  }
});

test("a new seat's plugin.json is not a trust change by itself", () => {
  const w = wheelhouse();
  try {
    w.change((put) => put("harnesses/dree/.agents/harness/plugin.json", manifest("dree", { description: "words" })));
    const r = w.run(diff);
    assert.deepEqual(r.json.trust, []);
  } finally {
    w.done();
  }
});

test("a seat folder that is gone is reported with the canonical uninstall id", () => {
  const w = wheelhouse();
  try {
    w.change(() => rmSync(join(w.wh, "harnesses", "dree"), { recursive: true, force: true }));
    const r = w.run(diff);
    assert.ok(r.json.notes.some((n) => /ynh uninstall local\/dree /.test(n)), r.json.notes.join("\n"));
  } finally {
    w.done();
  }
});

test("a scripts change needs restarts of every seat, and installs nothing", () => {
  const w = wheelhouse();
  try {
    w.change((put) => put("scripts/wake.sh", "#!/bin/sh\n# v2\n"));
    const r = w.run(diff);
    assert.deepEqual(r.json.install, []);
    assert.deepEqual(r.json.scriptsChanged, ["scripts/wake.sh"]);
    assert.deepEqual(r.json.restart, ["dree", "eno", "hq", "wick"]);
    assert.doesNotMatch(w.log(), /ynh install/);
  } finally {
    w.done();
  }
});

test("docs-only changes need nothing", () => {
  const w = wheelhouse();
  try {
    w.change((put) => {
      put("docs/notes.md", "more\n");
      put("harnesses/dree/.agents/harness/pinned-skills.md", "pins2\n");
    });
    const r = w.run(["HEAD~1..HEAD", "--upstream"]);
    assert.deepEqual(r.json.install, []);
    assert.deepEqual(r.json.restart, []);
    assert.deepEqual(r.json.trust, []);
    assert.deepEqual(r.json.upstream.updates, []);
  } finally {
    w.done();
  }
});

test("a dry run prints the plan and runs nothing", () => {
  const w = wheelhouse();
  try {
    w.change((put) => put("AGENTS.md", "# hq, changed\n"));
    const r = w.run([...diff, "--dry-run"]);
    assert.equal(r.status, 0, r.stderr);
    assert.equal(r.json.dryRun, true);
    assert.equal(r.json.install.length, 4);
    assert.deepEqual(r.json.ran, []);
    assert.doesNotMatch(w.log(), /ynh install/);
    assert.equal(r.json.doctor, "skipped: dry run");
  } finally {
    w.done();
  }
});

test("a failed install is reported, the rest still run, and the exit is 3", () => {
  const w = wheelhouse();
  try {
    w.change((put) => put("AGENTS.md", "# hq, changed\n"));
    const r = w.run(diff, { YNH_FAIL: "harnesses/eno" });
    assert.equal(r.status, 3);
    assert.equal(r.json.failed, true);
    assert.equal(r.json.ran.filter((s) => !s.ok).length, 1);
    assert.match(w.log(), /install harnesses\/wick/);
  } finally {
    w.done();
  }
});

test("a seat that is not installed or not born is reported with the exact command", () => {
  const w = wheelhouse();
  try {
    writeFileSync(join(w.dir, "ls.json"), JSON.stringify(ynhLs(["hq", "eno", "dree", "wick"].filter((s) => s !== "dree"))));
    const r = w.run(["HEAD..HEAD"], { UNBORN: "wick dree" });
    assert.equal(r.status, 0, r.stderr);
    const by = Object.fromEntries(r.json.seatsNotReady.map((s) => [s.seat, s]));
    assert.equal(by.dree.install, "ynh install harnesses/dree");
    assert.match(by.dree.reminder, /the human's/);
    assert.equal(by.wick.install, null);
    assert.match(by.wick.reminder, /the dispatcher's/);
    assert.equal(by.eno, undefined);
  } finally {
    w.done();
  }
});

test("with no diff it offers ynh update for a stale wheelhouse include, and --update runs it and re-copies changed plugin scripts", () => {
  const w = wheelhouse();
  try {
    writeFileSync(join(w.dir, "ls.json"), JSON.stringify(ynhLs(SEATS.map(([c]) => c), "old", "new")));
    const pluginDir = join(w.dir, "plugin");
    write(pluginDir, "skills/wake/scripts/wake.sh", "#!/bin/sh\n# v2\n");
    write(pluginDir, "skills/patrol/scripts/patrol.sh", "#!/bin/sh\n# not carried here\n");

    const offer = w.run(["HEAD..HEAD", "--plugin", pluginDir]);
    assert.equal(offer.status, 0, offer.stderr);
    assert.deepEqual(offer.json.upstream.updates.map((u) => u.command).sort(), ["ynh update local/dree", "ynh update local/eno", "ynh update local/hq", "ynh update local/wick"]);
    assert.deepEqual(offer.json.upstream.pluginScriptsDiffer, ["scripts/wake.sh"]);
    assert.deepEqual(offer.json.upstream.pluginScriptsCopied, []);
    assert.doesNotMatch(w.log(), /ynh update/);
    assert.match(readFileSync(join(w.wh, "scripts", "wake.sh"), "utf8"), /v1/);

    const done = w.run(["HEAD..HEAD", "--update", "--plugin", pluginDir]);
    assert.equal(done.status, 0, done.stderr);
    assert.match(w.log(), /^ynh update local\/hq$/m);
    assert.deepEqual(done.json.upstream.pluginScriptsCopied, ["scripts/wake.sh"]);
    assert.match(readFileSync(join(w.wh, "scripts", "wake.sh"), "utf8"), /v2/);
    assert.equal(existsSync(join(w.wh, "scripts", "patrol.sh")), false);
    assert.deepEqual(done.json.restart, ["dree", "eno", "hq", "wick"]);
  } finally {
    w.done();
  }
});

test("an include ynh could not probe (no ref_available) is not offered an update", () => {
  const w = wheelhouse();
  try {
    const ls = ynhLs(SEATS.map(([c]) => c), "old", "new");
    for (const h of ls.harnesses) delete h.includes[0].ref_available;
    writeFileSync(join(w.dir, "ls.json"), JSON.stringify(ls));
    const r = w.run(["HEAD..HEAD"]);
    assert.deepEqual(r.json.upstream.updates, []);
  } finally {
    w.done();
  }
});

test("an up-to-date include and no diff offers nothing", () => {
  const w = wheelhouse();
  try {
    const r = w.run(["HEAD..HEAD"]);
    assert.deepEqual(r.json.upstream.updates, []);
    assert.deepEqual(r.json.install, []);
  } finally {
    w.done();
  }
});

test("a directory that is not a Wheelhouse is refused", () => {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-refresh-none-"));
  try {
    const r = spawnSync("bash", [refreshSh, "--dir", dir], { encoding: "utf8" });
    assert.equal(r.status, 2);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
