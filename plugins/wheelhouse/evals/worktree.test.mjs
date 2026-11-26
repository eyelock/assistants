// worktree.sh: add prints the policy path and appends the path to the bead's notes; list shows seat, repo, branch, bead
// and flags stale ones; remove refuses force-like cases (outside the layout, uncommitted, another
// seat's, a bead not closed). Real git repositories in a temp folder; bd is a stand-in that keeps
// notes and statuses in files and counts its calls.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const script = join(here, "..", "skills", "worktrees", "scripts", "worktree.sh");

const sh = (cwd, cmd, env = {}) =>
  spawnSync("bash", ["-c", cmd], {
    cwd,
    encoding: "utf8",
    env: { ...process.env, GIT_CONFIG_GLOBAL: "/dev/null", ...env },
  });
const git = (cwd, args) => {
  const r = sh(cwd, `git -c user.name=t -c user.email=t@example.com ${args}`);
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
};

// A folder with a Wheelhouse "ynw" and a checkout "widget" beside it, whose origin has develop.
function world({ policy = { layout: "{repo}/.worktrees/{seat}/{branch}" } } = {}) {
  const root = realpathSync(mkdtempSync(join(tmpdir(), "wheelhouse-worktree-")));
  const wh = join(root, "ynw");
  const widget = join(root, "widget");
  mkdirSync(wh);
  writeFileSync(join(wh, "AGENTS.md"), "# ynw\n\nRepositories: `widget`: `../widget`.\n");
  if (policy) writeFileSync(join(wh, "worktrees.json"), JSON.stringify(policy));
  git(root, "init -q --bare -b develop origin.git");
  git(root, "clone -q origin.git widget");
  git(widget, "checkout -q -b develop");
  writeFileSync(join(widget, "a.txt"), "a\n");
  git(widget, "add a.txt");
  git(widget, "commit -q -m first");
  git(widget, "push -q origin develop");
  const bin = join(root, "bin");
  mkdirSync(bin);
  const state = join(root, "bd");
  mkdirSync(state);
  writeFileSync(
    join(bin, "bd"),
    `#!/bin/bash
s="${state}"
echo "bd $*" >> "$s/calls"
case "$1" in
  update)
    # bd update <id> --append-notes <line> --actor <seat>
    printf '%s\\n' "$4" >> "$s/$2.notes"; echo "bd update $2 $5 $6" >> "$s/log" ;;
  list)
    # bd list --all --limit 0 --notes-contains <text> --json: one query over every bead's notes.
    want=""; while [ $# -gt 0 ]; do [ "$1" = --notes-contains ] && want="$2"; shift; done
    grep -liF -- "$want" "$s"/*.notes 2>/dev/null | while read -r f; do
      jq -R -s --arg id "$(basename "$f" .notes)" '{id:$id, notes:.}' "$f"; done | jq -s '.' ;;
  show) st=open; [ -f "$s/$2.closed" ] && st=closed; echo "[{\\"id\\":\\"$2\\",\\"status\\":\\"$st\\"}]" ;;
esac
`,
  );
  chmodSync(join(bin, "bd"), 0o755);
  const run = (args, env = {}) =>
    spawnSync("bash", [script, ...args, "--dir", wh], {
      encoding: "utf8",
      env: {
        ...process.env,
        GIT_CONFIG_GLOBAL: "/dev/null",
        PATH: `${bin}:${process.env.PATH}`,
        WORKTREE_SCRATCHPAD: join(root, "scratch"),
        ...env,
      },
    });
  return {
    root,
    wh,
    widget,
    state,
    run,
    close: (id) => writeFileSync(join(state, `${id}.closed`), ""),
  };
}
const done = (w) => rmSync(w.root, { recursive: true, force: true });

test("add prints only the policy path, keeps the slash and notes the bead", () => {
  const w = world();
  try {
    const r = w.run([
      "add",
      "--seat",
      "albarn",
      "--repo",
      "widget",
      "--branch",
      "albarn/feat-x",
      "--bead",
      "ynw-1",
    ]);
    assert.equal(r.status, 0, r.stderr);
    const want = join(w.root, "widget", ".worktrees", "albarn", "albarn", "feat-x");
    assert.equal(r.stdout, `${want}\n`);
    assert.ok(existsSync(join(want, "a.txt")));
    assert.equal(git(w.widget, "branch --list albarn/feat-x").includes("albarn/feat-x"), true);
    assert.match(
      readFileSync(join(w.state, "ynw-1.notes"), "utf8"),
      new RegExp(`^Worktree: ${want}$`, "m"),
    );
    assert.match(readFileSync(join(w.state, "log"), "utf8"), /--actor albarn/);
  } finally {
    done(w);
  }
});

test("with no worktrees.json the worktree goes under the scratchpad", () => {
  const w = world({ policy: null });
  try {
    const r = w.run(["add", "--seat", "albarn", "--repo", "widget", "--branch", "albarn/y"]);
    assert.equal(r.status, 0, r.stderr);
    assert.equal(r.stdout, `${join(w.root, "scratch", "widget", "albarn", "y")}\n`);
  } finally {
    done(w);
  }
});

test("add refuses to create a branch outside the seat's prefix, and a bad branch name", () => {
  const w = world();
  try {
    let r = w.run(["add", "--seat", "albarn", "--repo", "widget", "--branch", "feat/x"]);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /does not start with 'albarn\/'/);
    r = w.run(["add", "--seat", "albarn", "--repo", "widget", "--branch", "albarn/../x"]);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /not a usable branch name/);
    r = w.run(["add", "--seat", "albarn", "--repo", "nope", "--branch", "albarn/x"]);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /no checkout known/);
  } finally {
    done(w);
  }
});

test("add checks out an existing branch whatever its prefix", () => {
  const w = world();
  try {
    git(w.widget, "branch hannett/pr-1 develop");
    const r = w.run(["add", "--seat", "hannett", "--repo", "widget", "--branch", "hannett/pr-1"]);
    assert.equal(r.status, 0, r.stderr);
  } finally {
    done(w);
  }
});

test("list shows seat, repo, branch, bead and path, and flags a closed bead", () => {
  const w = world();
  try {
    w.run([
      "add",
      "--seat",
      "albarn",
      "--repo",
      "widget",
      "--branch",
      "albarn/a",
      "--bead",
      "ynw-1",
    ]);
    w.run(["add", "--seat", "gahan", "--repo", "widget", "--branch", "gahan/b", "--bead", "ynw-2"]);
    w.close("ynw-2");
    const r = w.run(["list"]);
    assert.equal(r.status, 0, r.stderr);
    assert.ok(r.stdout, r.stderr);
    const rows = JSON.parse(r.stdout);
    assert.equal(rows.length, 2);
    const a = rows.find((x) => x.seat === "albarn");
    assert.deepEqual([a.repo, a.branch, a.bead, a.stale], ["widget", "albarn/a", "ynw-1", false]);
    const g = rows.find((x) => x.seat === "gahan");
    assert.equal(g.stale, true);
    assert.match(g.why, /ynw-2 is closed/);
    assert.deepEqual(
      JSON.parse(w.run(["list", "--stale"]).stdout).map((x) => x.seat),
      ["gahan"],
    );
  } finally {
    done(w);
  }
});

test("list flags a branch whose upstream is gone as merged", () => {
  const w = world();
  try {
    const p = w
      .run(["add", "--seat", "albarn", "--repo", "widget", "--branch", "albarn/m"])
      .stdout.trim();
    git(p, "push -q -u origin albarn/m");
    git(w.widget, "push -q origin --delete albarn/m");
    git(w.widget, "fetch -q --prune");
    const rows = JSON.parse(w.run(["list"]).stdout);
    assert.equal(rows[0].stale, true);
    assert.match(rows[0].why, /merged/);
  } finally {
    done(w);
  }
});

test("remove: the owner removes a clean worktree; uncommitted work, another seat's and outside paths are refused", () => {
  const w = world();
  try {
    const p = w
      .run([
        "add",
        "--seat",
        "albarn",
        "--repo",
        "widget",
        "--branch",
        "albarn/r",
        "--bead",
        "ynw-3",
      ])
      .stdout.trim();
    let r = w.run(["remove", p, "--seat", "gahan"]);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /may remove only its own/);
    r = w.run(["remove", p, "--seat", "marr"]);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /not closed/);
    writeFileSync(join(p, "new.txt"), "x");
    r = w.run(["remove", p, "--seat", "albarn"]);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /uncommitted/);
    assert.ok(existsSync(p));
    rmSync(join(p, "new.txt"));
    r = w.run(["remove", w.widget, "--seat", "albarn"]);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /not a worktree of the policy layout/);
    r = w.run(["remove", p, "--seat", "albarn"]);
    assert.equal(r.status, 0, r.stderr);
    assert.ok(!existsSync(p));
  } finally {
    done(w);
  }
});

test("remove: marr may remove another seat's worktree once its bead is closed", () => {
  const w = world();
  try {
    const p = w
      .run([
        "add",
        "--seat",
        "albarn",
        "--repo",
        "widget",
        "--branch",
        "albarn/c",
        "--bead",
        "ynw-4",
      ])
      .stdout.trim();
    w.close("ynw-4");
    const r = w.run(["remove", p, "--seat", "marr"]);
    assert.equal(r.status, 0, r.stderr);
    assert.ok(!existsSync(p));
  } finally {
    done(w);
  }
});

test("list and remove make a bounded number of bd calls, however many beads the graph holds", () => {
  const w = world();
  try {
    const paths = [];
    for (let i = 1; i <= 3; i++) {
      paths.push(
        w
          .run([
            "add",
            "--seat",
            "albarn",
            "--repo",
            "widget",
            "--branch",
            `albarn/n${i}`,
            "--bead",
            `ynw-${i}`,
          ])
          .stdout.trim(),
      );
    }
    // A graph of 2000 beads that have nothing to do with these worktrees.
    for (let i = 100; i < 2100; i++) writeFileSync(join(w.state, `ynw-${i}.notes`), "unrelated\n");
    const calls = () =>
      existsSync(join(w.state, "calls"))
        ? readFileSync(join(w.state, "calls"), "utf8").trim().split("\n").length
        : 0;
    // One worktree with no bead at all: it must not scan the graph either.
    git(w.widget, "branch albarn/nobead develop");
    w.run(["add", "--seat", "albarn", "--repo", "widget", "--branch", "albarn/nobead"]);
    rmSync(join(w.state, "calls"), { force: true });
    const r = w.run(["list"]);
    assert.equal(r.status, 0, r.stderr);
    const rows = JSON.parse(r.stdout);
    assert.equal(rows.length, 4);
    assert.deepEqual(
      rows
        .filter((x) => x.bead)
        .map((x) => x.bead)
        .sort(),
      ["ynw-1", "ynw-2", "ynw-3"],
    );
    // One bead lookup and at most one status lookup per worktree: never a call per bead.
    assert.ok(
      calls() <= 2 * rows.length,
      `list made ${calls()} bd calls for ${rows.length} worktrees`,
    );
    w.close("ynw-1");
    rmSync(join(w.state, "calls"), { force: true });
    const rm = w.run(["remove", paths[0], "--seat", "marr"]);
    assert.equal(rm.status, 0, rm.stderr);
    assert.ok(calls() <= 2, `remove made ${calls()} bd calls`);
  } finally {
    done(w);
  }
});

test("the script has no way to force, prune, move, lock or repair", () => {
  const src = readFileSync(script, "utf8")
    .split("\n")
    .filter((l) => !l.trim().startsWith("#"))
    .join("\n");
  assert.doesNotMatch(
    src,
    /worktree (prune|move|lock|repair)|--force|worktree remove -f|worktree add -f/,
  );
  const w = world();
  try {
    assert.equal(w.run(["remove", "/x", "--seat", "albarn", "--force"]).status, 1);
  } finally {
    done(w);
  }
});
