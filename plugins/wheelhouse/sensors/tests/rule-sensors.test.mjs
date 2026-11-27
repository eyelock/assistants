// The rule sensors (sensors/rules/*.sh): each passes on the clean fixture and fails on its own tripping
// fixture, offline and with no ynh on the PATH, and the plugin's manifest declares each as a blocking
// command sensor whose reference is that tripping fixture. Cases past the fixtures copy the clean
// Wheelhouse into a scratch directory, break one thing and run the real script there.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  appendFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const rules = join(plugin, "sensors", "rules");
const fixtures = join(plugin, "sensors", "fixtures");

const SENSORS = [
  "includes-pinned",
  "references-exist",
  "roster-consistent",
  "no-forked-scripts",
  "work-in-beads",
];

// A PATH that holds bash, jq and the coreutils the scripts use and nothing else, so no ynh, ynm, bd or gh.
function bareBin() {
  const bin = mkdtempSync(join(tmpdir(), "sensor-bin-"));
  for (const tool of [
    "bash",
    "jq",
    "grep",
    "sed",
    "sort",
    "tr",
    "dirname",
    "basename",
    "head",
    "cat",
  ]) {
    const found = spawnSync("/usr/bin/env", ["bash", "-c", `command -v ${tool}`], {
      encoding: "utf8",
    }).stdout.trim();
    if (found) symlinkSync(found, join(bin, tool));
  }
  return bin;
}
const bin = bareBin();

function run(sensor, cwd) {
  const r = spawnSync(join(rules, `${sensor}.sh`), [], {
    cwd,
    encoding: "utf8",
    env: { PATH: bin, HOME: tmpdir() },
  });
  return { code: r.status, out: r.stdout + r.stderr };
}

function scratch() {
  const dir = mkdtempSync(join(tmpdir(), "sensor-wheelhouse-"));
  cpSync(join(fixtures, "clean"), dir, { recursive: true });
  return dir;
}

function edit(dir, file, fn) {
  const path = join(dir, file);
  writeFileSync(path, fn(readFileSync(path, "utf8")));
}

test("the plugin declares each rule sensor as a blocking command sensor with a tripping fixture", () => {
  const manifest = JSON.parse(
    readFileSync(join(plugin, ".agents", "harness", "plugin.json"), "utf8"),
  );
  assert.deepEqual(Object.keys(manifest.sensors).sort(), [...SENSORS].sort());
  for (const name of SENSORS) {
    const s = manifest.sensors[name];
    assert.equal(s.tolerance, "blocking", name);
    assert.equal(s.source.command, `"$YNH_HARNESS_DIR/sensors/rules/${name}.sh"`);
    assert.deepEqual(s.reference, { path: `sensors/fixtures/${name}`, expect: "fail" });
    assert.ok(existsSync(join(rules, `${name}.sh`)), `${name}.sh exists`);
  }
});

test("every script under sensors/rules is a declared sensor", () => {
  assert.deepEqual(
    readdirSync(rules)
      .filter((f) => f.endsWith(".sh"))
      .map((f) => f.replace(/\.sh$/, ""))
      .sort(),
    [...SENSORS].sort(),
  );
});

for (const name of SENSORS) {
  test(`${name}.sh passes on the clean fixture, with no output`, () => {
    const r = run(name, join(fixtures, "clean"));
    assert.equal(r.code, 0, r.out);
    assert.equal(r.out, "");
  });

  test(`${name}.sh fails on its tripping fixture, one line per violation`, () => {
    const r = run(name, join(fixtures, name));
    assert.equal(r.code, 1, r.out);
    assert.ok(r.out.trim().split("\n").length >= 1);
    assert.match(r.out, /Fix:/);
  });
}

test("includes-pinned.sh names the manifest and the include, and leaves local and pinned includes alone", () => {
  const r = run("includes-pinned", join(fixtures, "includes-pinned"));
  assert.match(
    r.out,
    /^\.agents\/harness\/plugin\.json: the include https:\/\/github\.com\/example\/plugin has no ref/,
  );
  const dir = scratch();
  edit(dir, "harnesses/eno/.agents/harness/plugin.json", (t) =>
    t.replace("../..", "/somewhere/else"),
  );
  assert.equal(run("includes-pinned", dir).code, 0);
  rmSync(dir, { recursive: true });
});

test("includes-pinned.sh also reads a seat's delegates and the desk's own includes", () => {
  const dir = scratch();
  edit(dir, "harnesses/eno/.agents/harness/plugin.json", (t) =>
    t.replace(
      '"includes": [',
      '"delegates_to": [{ "git": "https://github.com/example/other" }], "includes": [',
    ),
  );
  const r = run("includes-pinned", dir);
  assert.equal(r.code, 1);
  assert.match(
    r.out,
    /harnesses\/eno\/.*the delegate https:\/\/github\.com\/example\/other has no ref/,
  );
  rmSync(dir, { recursive: true });
});

test("includes-pinned.sh reports a manifest that is not JSON", () => {
  const dir = scratch();
  writeFileSync(join(dir, "harnesses/eno/.agents/harness/plugin.json"), "{not json");
  const r = run("includes-pinned", dir);
  assert.equal(r.code, 1);
  assert.match(r.out, /not readable JSON/);
  rmSync(dir, { recursive: true });
});

test("references-exist.sh names the file, the line and the missing path", () => {
  const r = run("references-exist", join(fixtures, "references-exist"));
  assert.match(
    r.out,
    /^harnesses\/eno\/AGENTS\.md:\d+: names the path scripts\/missing-script\.sh/,
  );
});

test("references-exist.sh flags a missing skill and a seat that is not in the roster", () => {
  const dir = scratch();
  appendFileSync(
    join(dir, "harnesses/eno/AGENTS.md"),
    "\nRun the ghost-town skill, then `bd update --actor nobody`.\n",
  );
  const r = run("references-exist", dir);
  assert.equal(r.code, 1);
  assert.match(r.out, /names the skill ghost-town/);
  assert.match(r.out, /names the seat or human nobody/);
  rmSync(dir, { recursive: true });
});

test("references-exist.sh accepts a skill of the plugin, a placeholder, another checkout and a fenced block", () => {
  const dir = scratch();
  appendFileSync(
    join(dir, "harnesses/eno/AGENTS.md"),
    [
      "",
      "Use the wake skill and the work-graph skill; keep notes in `seat/eno`.",
      "Open `harnesses/<command>/AGENTS.md`, see `../ynh/docs/x.md` and `/Users/someone/open-pr.sh`.",
      "```",
      "`scripts/not-read-inside-a-fence.sh`",
      "```",
      "",
    ].join("\n"),
  );
  const r = run("references-exist", dir);
  assert.equal(r.code, 0, r.out);
  rmSync(dir, { recursive: true });
});

test("references-exist.sh accepts a skill picked by a manifest and a skill folder of the Wheelhouse", () => {
  const dir = scratch();
  edit(dir, "harnesses/eno/.agents/harness/plugin.json", (t) =>
    t.replace('"skills/roster"]', '"skills/roster", "skills/ynm-memory"]'),
  );
  appendFileSync(join(dir, "AGENTS.md"), "\nSee the ynm-memory skill and the roster skill.\n");
  assert.equal(run("references-exist", dir).code, 0);
  rmSync(dir, { recursive: true });
});

test("roster-consistent.sh names the folder with no roster entry", () => {
  const r = run("roster-consistent", join(fixtures, "roster-consistent"));
  assert.match(r.out, /^harnesses\/wick: no seat in the roster has this harness/m);
});

test("roster-consistent.sh flags a roster seat with no folder, a stray delegate and a seat not started by its name", () => {
  const dir = scratch();
  edit(dir, "skills/roster/assets/roster.json", (t) =>
    t.replace(
      '{ "name": "Eno"',
      '{ "name": "Ghost", "group": "crew", "command": "ghost", "harness": "harnesses/ghost" },\n    { "name": "Eno"',
    ),
  );
  edit(dir, ".agents/harness/plugin.json", (t) =>
    t.replace(
      '"path": "harnesses/eno" }',
      '"path": "harnesses/eno" }, { "git": ".", "path": "harnesses/lost" }',
    ),
  );
  edit(dir, "harnesses/eno/.agents/harness/plugin.json", (t) =>
    t.replace("--seat eno ", "--seat someone-else "),
  );
  const r = run("roster-consistent", dir);
  assert.equal(r.code, 1);
  assert.match(r.out, /seat ghost names harness harnesses\/ghost/);
  assert.match(r.out, /delegate harnesses\/lost is no roster seat's harness/);
  assert.match(r.out, /seats wired: .*eno/);
  rmSync(dir, { recursive: true });
});

test("roster-consistent.sh requires exactly one default human", () => {
  for (const [humans, expected] of [
    ['[{ "name": "A", "command": "a" }]', /default human: the roster has no default human/],
    [
      '[{ "name": "A", "command": "a", "default": true }, { "name": "B", "command": "b", "default": true }]',
      /default human: the roster has 2 default humans/,
    ],
  ]) {
    const dir = scratch();
    edit(dir, "skills/roster/assets/roster.json", (t) =>
      t.replace(/"humans": \[.*\]/, `"humans": ${humans}`),
    );
    const r = run("roster-consistent", dir);
    assert.equal(r.code, 1);
    assert.match(r.out, expected);
    rmSync(dir, { recursive: true });
  }
});

test("roster-consistent.sh flags a charter whose heading, identity line or byline names another seat", () => {
  const dir = scratch();
  edit(dir, "harnesses/eno/AGENTS.md", (t) =>
    t
      .replace("# Eno", "# Enoch")
      .replace("You are Eno, the eno seat", "You are Eno, the enoch seat"),
  );
  appendFileSync(join(dir, "harnesses/eno/AGENTS.md"), "\nSign `**Hq** · fixture seat`.\n");
  appendFileSync(join(dir, "AGENTS.md"), "\nSign `**Nobody** · fixture seat`.\n");
  const r = run("roster-consistent", dir);
  assert.equal(r.code, 1);
  assert.match(r.out, /heading is "Enoch", but the roster names this seat Eno/);
  assert.match(r.out, /says "You are Eno, the enoch seat", but the roster has Eno, command eno/);
  assert.match(r.out, /byline names Hq, but this is Eno's charter/);
  assert.match(r.out, /AGENTS\.md: byline names Nobody, who is no seat in the roster/);
  rmSync(dir, { recursive: true });
});

test("roster-consistent.sh says so when there is no roster", () => {
  const dir = scratch();
  rmSync(join(dir, "skills/roster/assets/roster.json"));
  const r = run("roster-consistent", dir);
  assert.equal(r.code, 1);
  assert.match(r.out, /no readable roster/);
  rmSync(dir, { recursive: true });
});

test("no-forked-scripts.sh lists each copy of a plugin script", () => {
  const dir = scratch();
  mkdirSync(join(dir, "scripts"));
  for (const f of ["wake.sh", "memory.sh", "own-script.sh"])
    writeFileSync(join(dir, "scripts", f), "#!/bin/sh\n");
  const r = run("no-forked-scripts", dir);
  assert.equal(r.code, 1);
  assert.match(r.out, /scripts\/wake\.sh/);
  assert.match(r.out, /scripts\/memory\.sh/);
  assert.doesNotMatch(r.out, /own-script/);
  rmSync(dir, { recursive: true });
});

test("work-in-beads.sh fails with no work graph, and on each piece of Beads' own agent setup", () => {
  const none = scratch();
  rmSync(join(none, ".beads"), { recursive: true });
  const r = run("work-in-beads", none);
  assert.equal(r.code, 1);
  assert.match(r.out, /no \.beads\//);
  rmSync(none, { recursive: true });

  for (const [file, text] of [
    [".claude/settings.json", '{"hooks": "bd prime"}'],
    [".cursor/rules/beads.mdc", "beads"],
  ]) {
    const dir = scratch();
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    writeFileSync(join(dir, file), text);
    const t = run("work-in-beads", dir);
    assert.equal(t.code, 1, file);
    assert.match(t.out, /Beads' own agent setup is present/);
    rmSync(dir, { recursive: true });
  }
});

test("every sensor answers --help without a Wheelhouse", () => {
  for (const name of SENSORS) {
    const r = spawnSync(join(rules, `${name}.sh`), ["--help"], {
      encoding: "utf8",
      env: { PATH: bin },
    });
    assert.equal(r.status, 0, name);
    assert.match(r.stdout, new RegExp(`Usage: ${name}\\.sh`));
  }
});
