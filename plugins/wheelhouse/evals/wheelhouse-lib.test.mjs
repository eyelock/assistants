// wheelhouse-lib.sh is the helpers every wheelhouse script shares. Each case sources the real
// library in bash and calls one helper, with stubs of bd and ynm where it calls them.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, cpSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const lib = join(dirname(fileURLToPath(import.meta.url)), "..", "skills", "work-graph", "scripts", "wheelhouse-lib.sh");

function scratch() {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-lib-"));
  mkdirSync(join(dir, "bin"));
  return { dir, done: () => rmSync(dir, { recursive: true, force: true }) };
}
const stub = (dir, name, body) => {
  writeFileSync(join(dir, "bin", name), `#!/bin/sh\n${body}\n`);
  chmodSync(join(dir, "bin", name), 0o755);
};
// Runs a bash snippet after sourcing the library, with the stubs first on PATH.
const run = (dir, snippet, { path, input, env } = {}) =>
  spawnSync("/bin/bash", ["-c", `. "${lib}"; ${snippet}`], {
    cwd: dir,
    input,
    encoding: "utf8",
    env: { ...process.env, PATH: path ?? `${join(dir, "bin")}:${process.env.PATH}`, ...env },
  });

test("limited passes the command's output and exit code through", () => {
  const s = scratch();
  try {
    const ok = run(s.dir, "limited 5 echo hi");
    assert.equal(ok.stdout, "hi\n");
    assert.equal(run(s.dir, "limited 5 sh -c 'exit 7'").status, 7);
  } finally {
    s.done();
  }
});

test("limited gives up with 142 and kills the command's whole process group", () => {
  const s = scratch();
  try {
    // The child sleeps in a grandchild that holds the output pipe: without the group kill the
    // read would last the whole sleep.
    const began = Date.now();
    const r = run(s.dir, `limited 1 sh -c 'sleep 30 & wait' | cat`);
    assert.ok(Date.now() - began < 10000, "the pipe closed soon after the limit");
    const rc = run(s.dir, "limited 1 sh -c 'sleep 30 & wait'").status;
    assert.equal(rc, 142);
    assert.equal(r.status, 0);
  } finally {
    s.done();
  }
});

test("limited without perl runs the command unbounded and says so once", () => {
  const s = scratch();
  try {
    for (const tool of ["sleep", "sh"]) symlinkSync(spawnSync("which", [tool], { encoding: "utf8" }).stdout.trim(), join(s.dir, "bin", tool));
    const r = run(s.dir, "limited 5 sleep 0; limited 5 sleep 0; echo done", { path: join(s.dir, "bin") });
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /done/);
    assert.match(r.stderr, /perl is not installed, so 'sleep' runs with no time limit/);
    assert.equal(r.stderr.match(/perl is not installed/g).length, 1);
  } finally {
    s.done();
  }
});

test("die prints the prefixed message and exits with the code; need dies 3 for a missing tool", () => {
  const s = scratch();
  try {
    const d = run(s.dir, 'WL_PREFIX="x: "; die 4 "went wrong"');
    assert.equal(d.status, 4);
    assert.equal(d.stderr, "x: went wrong\n");
    const n = run(s.dir, "need no-such-tool-here");
    assert.equal(n.status, 3);
    assert.match(n.stderr, /no-such-tool-here is not installed/);
    assert.equal(run(s.dir, "need sh; echo fine").stdout, "fine\n");
  } finally {
    s.done();
  }
});

test("bd_data and bd_first read a bare result and a {data} envelope the same way", () => {
  const s = scratch();
  try {
    for (const json of ['[{"id":"a"},{"id":"b"}]', '{"data":[{"id":"a"},{"id":"b"}]}']) {
      assert.equal(run(s.dir, "bd_data", { input: json }).stdout.trim(), '[{"id":"a"},{"id":"b"}]');
      assert.equal(run(s.dir, "bd_first", { input: json }).stdout.trim(), '{"id":"a"}');
    }
    assert.equal(run(s.dir, "bd_first", { input: '{"data":{"id":"c"}}' }).stdout.trim(), '{"id":"c"}');
  } finally {
    s.done();
  }
});

test("wl_valid_command takes lower-case letters, digits and hyphens, and nothing else", () => {
  const s = scratch();
  try {
    for (const ok of ["gahan", "a1", "x-y"]) assert.equal(run(s.dir, `wl_valid_command '${ok}'`).status, 0, ok);
    for (const bad of ["", "-x", "Gahan", "a b", "a.b", "a_b", "../x"]) assert.notEqual(run(s.dir, `wl_valid_command '${bad}'`).status, 0, bad);
  } finally {
    s.done();
  }
});

test("wl_backend is ynm by default, reads wheelhouse.json, and refuses anything else with 2", () => {
  const s = scratch();
  try {
    assert.equal(run(s.dir, "wl_backend .").stdout, "ynm\n");
    writeFileSync(join(s.dir, "wheelhouse.json"), '{"memory":"beads"}');
    assert.equal(run(s.dir, "wl_backend .").stdout, "beads\n");
    writeFileSync(join(s.dir, "wheelhouse.json"), '{"memory":"other"}');
    const r = run(s.dir, "wl_backend .");
    assert.equal(r.status, 2);
    assert.equal(r.stdout, "other\n");
  } finally {
    s.done();
  }
});

test("roster helpers: seat, trial seat, default humans, who births a seat", () => {
  const s = scratch();
  try {
    const roster = join(s.dir, "roster.json");
    writeFileSync(
      roster,
      JSON.stringify({
        seats: [
          { command: "hq", group: "desk" },
          { command: "eno", group: "crew", "seated-by": "Stakker" },
          { command: "gahan", group: "workers" },
          { command: "dree", group: "crew" },
        ],
        humans: [{ command: "stakker", default: true }, { command: "other" }],
      }),
    );
    mkdirSync(join(s.dir, "harnesses", "trial"), { recursive: true });
    writeFileSync(join(s.dir, "harnesses", "trial", "AGENTS.md"), "# trial\n");
    assert.equal(run(s.dir, `wl_is_seat "${roster}" . gahan`).status, 0);
    assert.equal(run(s.dir, `wl_is_seat "${roster}" . trial`).status, 0);
    assert.equal(run(s.dir, `wl_is_trial_seat . gahan`).status, 1);
    assert.equal(run(s.dir, `wl_is_seat "${roster}" . nobody`).status, 1);
    assert.equal(run(s.dir, `wl_default_humans "${roster}"`).stdout, "1\n");
    assert.equal(run(s.dir, `wl_born_by "${roster}" gahan`).stdout, "the dispatcher\n");
    assert.equal(run(s.dir, `wl_born_by "${roster}" eno`).stdout, "Stakker\n");
    assert.equal(run(s.dir, `wl_born_by "${roster}" dree`).stdout, "the human\n");
  } finally {
    s.done();
  }
});

test("wl_dolt_remote says yes, no or busy, and busy when bd gives up or fails", () => {
  const s = scratch();
  try {
    stub(s.dir, "bd", 'echo \'{"data":[{"name":"origin"}]}\'');
    assert.equal(run(s.dir, "wl_dolt_remote 5").stdout, "yes\n");
    stub(s.dir, "bd", "echo '[]'");
    assert.equal(run(s.dir, "wl_dolt_remote 5").stdout, "no\n");
    stub(s.dir, "bd", "exit 1");
    assert.equal(run(s.dir, "wl_dolt_remote 5").stdout, "busy\n");
    stub(s.dir, "bd", "sleep 30");
    assert.equal(run(s.dir, "wl_dolt_remote 1").stdout, "busy\n");
  } finally {
    s.done();
  }
});

test("wl_identity_pinned reads the seat's own namespace from ynm, and returns 1 when memory can't say", () => {
  const s = scratch();
  try {
    stub(s.dir, "ynm", 'echo \'[{"namespace":"seat/gahan","pinned":true}]\'');
    assert.equal(run(s.dir, "wl_identity_pinned ynm . gahan").stdout, "yes\n");
    assert.equal(run(s.dir, "wl_identity_pinned ynm . eno").stdout, "no\n", "the namespace is the seat's own");
    stub(s.dir, "ynm", "exit 1");
    assert.equal(run(s.dir, "wl_identity_pinned ynm . gahan").status, 1);
    assert.equal(run(s.dir, "wl_identity_pinned other . gahan").status, 1);
  } finally {
    s.done();
  }
});

test("WL_JQ_MODELS resolves a seat's model from its tier, group default or per-vendor override", () => {
  const s = scratch();
  try {
    const roster = {
      models: { groups: { workers: "fast" }, tiers: { deep: { claude: "big" } } },
      seats: [
        { command: "a", group: "workers" },
        { command: "b", group: "crew", model: "deep" },
        { command: "c", group: "crew", model: "deep", models: { claude: "haiku" } },
        { command: "d", group: "crew" },
      ],
    };
    const r = run(s.dir, `jq -c "$WL_JQ_MODELS"'[wl_model("claude") | [.seat, .model]]'`, { input: JSON.stringify(roster) });
    assert.deepEqual(JSON.parse(r.stdout), [["a", "sonnet"], ["b", "big"], ["c", "haiku"], ["d", null]]);
  } finally {
    s.done();
  }
});

// ynh delivers only skill folders to a seat. A seat picks wake and work-graph (the desk picks
// them all), so each skill's scripts/ is copied alone into <seat>/.claude/skills/<skill>/ and
// every script that sources the library must still find it there: no repository tree, no lib/.
test("every script finds the library from an installed seat layout of picked skill folders only", () => {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-install-"));
  try {
    const skills = join(dirname(lib), "..", "..");
    const installed = join(dir, ".claude", "skills");
    const picked = ["wake", "work-graph", "add-seat", "doctor", "refresh", "patrol"];
    for (const name of picked) cpSync(join(skills, name), join(installed, name), { recursive: true });
    const scripts = readdirSync(installed)
      .flatMap((name) => readdirSync(join(installed, name, "scripts")).filter((f) => f.endsWith(".sh")).map((f) => join(installed, name, "scripts", f)))
      .filter((f) => readFileSync(f, "utf8").includes("wheelhouse-lib.sh") && !f.endsWith("wheelhouse-lib.sh"));
    assert.ok(scripts.length >= 10, `found ${scripts.length} scripts that source the library`);
    for (const script of scripts) {
      const r = spawnSync("/bin/bash", [script, "--help"], { cwd: dir, encoding: "utf8" });
      assert.notEqual(r.status, 3, `${script} could not find the library: ${r.stderr}`);
      assert.doesNotMatch(r.stderr, /wheelhouse-lib\.sh not found/, script);
    }
    // A seat that picks only wake and work-graph still runs its own scripts.
    rmSync(join(installed, "add-seat"), { recursive: true });
    rmSync(join(installed, "doctor"), { recursive: true });
    rmSync(join(installed, "refresh"), { recursive: true });
    rmSync(join(installed, "patrol"), { recursive: true });
    const wake = spawnSync("/bin/bash", [join(installed, "wake", "scripts", "wake.sh"), "--help"], { encoding: "utf8" });
    assert.equal(wake.status, 0, wake.stderr);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
