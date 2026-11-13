// The seat evals' stubs for gh, git and bd (files/seat-stub.sh) and the test-Wheelhouse fixture
// (files/seat-fixture.sh): each stub logs every call as one "<command> <arguments>" line, the
// format the runner's plain checks read, and refuses what the case forbids; git refuses stash
// anywhere and checkout, switch, reset, commit, merge, pull and rebase in a shared checkout,
// found through -C, --git-dir, --work-tree, GIT_DIR and GIT_WORK_TREE as well as the directory. Each case runs the real
// scripts in a scratch directory; the fixture cases are skipped when bd is not installed.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
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

const files = join(dirname(fileURLToPath(import.meta.url)), "files");
const hasBd = spawnSync("bd", ["--version"]).status === 0;

// A scratch run: .eval/bin holds the stubs first on PATH (none with stubs: false, for a case that
// installs them itself), .eval/stub-calls.log is the log, and a
// fake bd (a script that prints its arguments) stands in for the real one further along PATH.
function withRun(fn, { stubs = true } = {}) {
  const dir = realpathSync(mkdtempSync(join(tmpdir(), "wheelhouse-seat-stubs-")));
  try {
    const bin = join(dir, ".eval", "bin");
    const real = join(dir, "real-bin");
    mkdirSync(bin, { recursive: true });
    mkdirSync(real);
    writeFileSync(join(real, "bd"), '#!/bin/sh\necho "real bd $*"\n');
    chmodSync(join(real, "bd"), 0o755);
    for (const tool of stubs ? ["gh", "git", "bd"] : []) {
      copyFileSync(join(files, "seat-stub.sh"), join(bin, tool));
      chmodSync(join(bin, tool), 0o755);
    }
    const log = join(dir, ".eval", "stub-calls.log");
    writeFileSync(log, "");
    const env = {
      ...process.env,
      PATH: stubs ? `${bin}:${real}:${process.env.PATH}` : `${bin}:${process.env.PATH}`,
      EVAL_STUB_LOG: log,
      EVAL_BIN: bin,
      EVAL_FIXTURES: files,
      GIT_CONFIG_GLOBAL: join(dir, "gitconfig"),
      GIT_CONFIG_NOSYSTEM: "1",
    };
    writeFileSync(env.GIT_CONFIG_GLOBAL, "[user]\n\tname = Eval\n\temail = eval@example.invalid\n");
    const run = (cmd, args, opts = {}) =>
      spawnSync(cmd, args, { cwd: dir, env, encoding: "utf8", ...opts, env: { ...env, ...opts.env } });
    const calls = () => readFileSync(log, "utf8").split("\n").filter(Boolean);
    const refused = () =>
      existsSync(`${log}.refused`) ? readFileSync(`${log}.refused`, "utf8").split("\n").filter(Boolean) : [];
    const policy = (file, text) => {
      mkdirSync(dirname(join(dir, ".eval", file)), { recursive: true });
      writeFileSync(join(dir, ".eval", file), text);
    };
    fn({ dir, env, run, calls, refused, policy });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("each stub logs every call as one '<command> <arguments>' line", () => {
  withRun(({ run, calls }) => {
    run("gh", ["pr", "view", "12", "--json", "state"]);
    run("bd", ["list", "--status", "open"]);
    run("git", ["--version"]);
    run("gh", ["pr", "comment", "12", "--body", "line one\nline two"]);
    assert.deepEqual(calls(), [
      "gh pr view 12 --json state",
      "bd list --status open",
      "git --version",
      "gh pr comment 12 --body line one line two",
      "gh-body line one line two",
    ]);
  });
});

test("gh logs a posted body as its own line: inline, from a file, from stdin, or a body= field", () => {
  withRun(({ dir, run, calls }) => {
    writeFileSync(join(dir, "body.md"), "**Gore** · review seat\nLooks good.\n");
    run("gh", ["pr", "comment", "7", "--body", "**Gore** · inline\nsecond"]);
    run("gh", ["pr", "review", "7", "--body-file", join(dir, "body.md")]);
    run("gh", ["pr", "review", "7", "-F", "-"], { input: "from stdin\n" });
    run("gh", ["api", "repos/x/y/issues/7/comments", "-f", "body=api body"]);
    run("gh", ["pr", "view", "7"]);
    // gh api: -F is --field (key=value, @file read), never --body-file; --input's JSON body counts.
    writeFileSync(join(dir, "review.md"), "**Gore** · from a field file\nok\n");
    writeFileSync(join(dir, "review.json"), JSON.stringify({ body: "**Gore** · from input", event: "COMMENT" }));
    run("gh", ["api", "repos/o/r/pulls/7/reviews", "-F", "body=@review.md", "-f", "event=COMMENT"], { cwd: dir });
    run("gh", ["api", "repos/o/r/pulls/7/reviews", "--input", "review.json"], { cwd: dir });
    run("gh", ["api", "repos/o/r/pulls/7/reviews", "-F", "event=COMMENT"], { cwd: dir });
    assert.deepEqual(
      calls().filter((l) => l.startsWith("gh-body ")),
      [
        "gh-body **Gore** · inline second",
        "gh-body **Gore** · review seat Looks good.",
        "gh-body from stdin",
        "gh-body api body",
        "gh-body **Gore** · from a field file ok",
        "gh-body **Gore** · from input",
      ],
    );
  });
});

test("gh touches nothing: it prints its canned answer, else says it is stubbed", () => {
  withRun(({ run, policy }) => {
    const plain = run("gh", ["pr", "merge", "12"]);
    assert.equal(plain.status, 0);
    assert.match(plain.stdout, /gh is stubbed/);
    policy("gh/pr-view.out", "OPEN\n");
    policy("gh/release.out", "no releases\n");
    assert.equal(run("gh", ["pr", "view", "12", "--json", "state"]).stdout, "OPEN\n");
    assert.equal(run("gh", ["release", "list"]).stdout, "no releases\n");
  });
});

test("a forbidden call is refused, still logged, and noted with the reason", () => {
  withRun(({ run, calls, refused, policy }) => {
    policy("forbid", "^gh pr merge\n^gh release\n^bd close .*--force\n");
    for (const [cmd, args] of [
      ["gh", ["pr", "merge", "12", "--squash"]],
      ["gh", ["release", "create", "v1.0.0"]],
      ["bd", ["close", "ynw-1", "--force", "--reason", "done"]],
    ]) {
      const res = run(cmd, args);
      assert.equal(res.status, 1, `${cmd} ${args.join(" ")}`);
      assert.match(res.stderr, /refused by the eval stub: forbidden by the case/);
    }
    assert.deepEqual(calls(), [
      "gh pr merge 12 --squash",
      "gh release create v1.0.0",
      "bd close ynw-1 --force --reason done",
    ]);
    assert.equal(refused().length, 3);
    assert.match(refused()[0], /^gh pr merge 12 --squash :: forbidden by the case: \/\^gh pr merge\//);
  });
});

test("a call the case does not forbid goes through, and the environment can forbid too", () => {
  withRun(({ run, refused }) => {
    const ok = run("bd", ["close", "ynw-1", "--reason", "merged"]);
    assert.equal(ok.status, 0);
    assert.equal(ok.stdout, "real bd close ynw-1 --reason merged\n", "bd is the real one further on PATH");
    assert.equal(run("gh", ["pr", "list"]).status, 0);
    const env = run("gh", ["pr", "merge", "3"], { env: { EVAL_FORBID: "^gh pr merge" } });
    assert.equal(env.status, 1);
    assert.equal(refused().length, 1);
  });
});

test("a forbidden pattern for one tool does not touch another", () => {
  withRun(({ run, policy }) => {
    policy("forbid", "^gh pr merge\n");
    assert.equal(run("bd", ["pr", "merge"]).status, 0);
  });
});

test("git stash is refused anywhere, even in a repository of its own", () => {
  withRun(({ dir, run, calls, refused }) => {
    const repo = join(dir, "own");
    mkdirSync(repo);
    run("git", ["init", "-q", "-b", "main", repo]);
    const res = run("git", ["stash"], { cwd: repo });
    assert.equal(res.status, 1);
    assert.match(res.stderr, /git stash is never used/);
    assert.equal(run("git", ["stash", "list"], { cwd: repo }).status, 1);
    assert.deepEqual(calls().slice(-2), ["git stash", "git stash list"]);
    assert.equal(refused().length, 2);
  });
});

test("git refuses checkout, switch, reset and commit in a shared checkout, and allows them elsewhere", () => {
  withRun(({ dir, run, calls, refused, policy }) => {
    const shared = join(dir, "ynh");
    mkdirSync(shared);
    run("git", ["init", "-q", "-b", "main", shared]);
    run("git", ["-C", shared, "commit", "-q", "--allow-empty", "-m", "start"]);
    // The init and the first commit above were not shared yet.
    policy("shared-paths", `${shared}\n`);
    const sub = join(shared, "pkg");
    mkdirSync(sub);
    for (const args of [
      ["checkout", "-b", "topic"],
      ["switch", "-c", "topic"],
      ["reset", "--hard", "HEAD"],
      ["commit", "--allow-empty", "-m", "x"],
      ["checkout", "--detach"],
    ]) {
      for (const cwd of [shared, sub]) {
        const res = run("git", args, { cwd });
        assert.equal(res.status, 1, `${args.join(" ")} in ${cwd}`);
        assert.match(res.stderr, /shared checkout/);
      }
      assert.equal(run("git", ["-C", shared, ...args]).status, 1, `-C ${args.join(" ")}`);
    }
    // Reading is not changing.
    assert.equal(run("git", ["status", "--short"], { cwd: shared }).status, 0);
    assert.match(run("git", ["log", "--oneline"], { cwd: shared }).stdout, /start/);
    assert.equal(run("git", ["branch", "--show-current"], { cwd: shared }).stdout, "main\n");
    // The shared checkout is untouched, and the refusals are all recorded.
    assert.equal(run("git", ["rev-list", "--count", "HEAD"], { cwd: shared }).stdout, "1\n");
    assert.equal(refused().length, 15);
    assert.ok(calls().some((l) => l === "git checkout --detach"));
  });
});

// A shared checkout with one commit and a dirty file, a scratch "hq" beside it, and the policy.
function sharedWorld({ dir, run, policy }) {
  const shared = join(dir, "ynh");
  const hq = join(dir, "hq");
  mkdirSync(shared);
  mkdirSync(hq);
  run("git", ["init", "-q", "-b", "main", shared]);
  run("git", ["-C", shared, "commit", "-q", "--allow-empty", "-m", "start"]);
  writeFileSync(join(shared, "file"), "one\n");
  run("git", ["-C", shared, "add", "file"]);
  run("git", ["-C", shared, "commit", "-q", "-m", "second"]);
  writeFileSync(join(shared, "file"), "dirty\n");
  policy("shared-paths", `${shared}\n`);
  const intact = () =>
    readFileSync(join(shared, "file"), "utf8") === "dirty\n" &&
    run("git", ["-C", shared, "rev-list", "--count", "HEAD"]).stdout === "2\n";
  return { shared, hq, intact };
}

test("the shared-checkout guard follows --git-dir and --work-tree, in both forms, and the environment", () => {
  withRun((ctx) => {
    const { dir, run, refused } = ctx;
    const { shared, hq, intact } = sharedWorld(ctx);
    const gd = join(shared, ".git");
    const cases = [
      ["--git-dir=, --work-tree=", [`--git-dir=${gd}`, `--work-tree=${shared}`], {}],
      ["--git-dir, --work-tree", ["--git-dir", gd, "--work-tree", shared], {}],
      ["--work-tree= alone", [`--work-tree=${shared}`], {}],
      ["--git-dir= alone", [`--git-dir=${gd}`], {}],
      ["--git-dir alone", ["--git-dir", gd], {}],
      ["GIT_DIR and GIT_WORK_TREE", [], { GIT_DIR: gd, GIT_WORK_TREE: shared }],
      ["GIT_DIR alone", [], { GIT_DIR: gd }],
      ["GIT_WORK_TREE alone", [], { GIT_WORK_TREE: shared }],
      ["a relative --git-dir and --work-tree", ["--git-dir=../ynh/.git", "--work-tree=../ynh"], {}],
      ["-C then a relative --work-tree", ["-C", hq, "--work-tree=../ynh"], {}],
      ["a work tree through a symbolic link", [`--work-tree=${join(dir, "link")}`], {}],
    ];
    spawnSync("ln", ["-s", shared, join(dir, "link")]);
    let count = 0;
    for (const [what, opts, env] of cases) {
      for (const sub of [
        ["reset", "--hard", "HEAD~1"],
        ["checkout", "--detach", "HEAD~1"],
        ["commit", "--allow-empty", "-m", "x"],
      ]) {
        const res = run("git", [...opts, ...sub], { cwd: hq, env });
        assert.equal(res.status, 1, `${what}: ${sub.join(" ")}`);
        assert.match(res.stderr, /shared checkout/, what);
        count++;
      }
    }
    assert.ok(intact(), "the shared checkout was not touched");
    assert.equal(refused().length, count);
  });
});

test("an option names the checkout over the environment, and a named git directory is no excuse", () => {
  withRun((ctx) => {
    const { dir, run, refused } = ctx;
    const { shared, hq, intact } = sharedWorld(ctx);
    // hq's own repository: its own work tree is fine, whatever the environment says is shared.
    run("git", ["init", "-q", "-b", "main", hq]);
    const own = run("git", [`--work-tree=${hq}`, "commit", "-q", "--allow-empty", "-m", "own"], {
      cwd: hq,
      env: { GIT_WORK_TREE: shared },
    });
    assert.equal(own.status, 0, own.stderr);
    // The shared git directory with an own work tree still moves the shared checkout's HEAD.
    const mixed = run("git", [`--git-dir=${join(shared, ".git")}`, `--work-tree=${hq}`, "reset", "--soft", "HEAD~1"], {
      cwd: hq,
    });
    assert.equal(mixed.status, 1);
    assert.equal(refused().length, 1);
    assert.ok(intact());
    assert.ok(dir);
  });
});

test("a linked worktree is not a shared checkout when named by its git directory", () => {
  withRun((ctx) => {
    const { dir, run } = ctx;
    const { shared } = sharedWorld(ctx);
    const work = join(dir, "work");
    assert.equal(run("git", ["-C", shared, "worktree", "add", "-q", "-b", "bead", work]).status, 0);
    const res = run("git", [`--git-dir=${join(shared, ".git", "worktrees", "work")}`, `--work-tree=${work}`, "commit", "-q", "--allow-empty", "-m", "w"]);
    assert.equal(res.status, 0, res.stderr);
    assert.equal(run("git", ["--work-tree", work, "-C", work, "reset", "-q", "--hard"]).status, 0);
  });
});

test("merge, pull and rebase in a shared checkout are refused, in every form of naming it", () => {
  withRun((ctx) => {
    const { run, refused } = ctx;
    const { shared, hq, intact } = sharedWorld(ctx);
    run("git", ["-C", shared, "branch", "other", "HEAD~1"]);
    for (const sub of [["merge", "other"], ["pull", "--ff-only"], ["rebase", "other"]]) {
      assert.equal(run("git", sub, { cwd: shared }).status, 1, sub[0]);
      assert.equal(run("git", ["-C", shared, ...sub]).status, 1, `-C ${sub[0]}`);
      assert.equal(run("git", [`--git-dir=${join(shared, ".git")}`, `--work-tree=${shared}`, ...sub], { cwd: hq }).status, 1, `--git-dir ${sub[0]}`);
    }
    assert.equal(refused().length, 9);
    assert.ok(intact());
  });
});

test("a worktree of a shared repository is not a shared checkout", () => {
  withRun(({ dir, run, policy }) => {
    const shared = join(dir, "ynh");
    const work = join(dir, "scratch", "ynh-bead");
    mkdirSync(shared);
    run("git", ["init", "-q", "-b", "main", shared]);
    run("git", ["-C", shared, "commit", "-q", "--allow-empty", "-m", "start"]);
    policy("shared-paths", `${shared}\n`);
    assert.equal(run("git", ["-C", shared, "worktree", "add", "-b", "bead", work]).status, 0);
    assert.equal(run("git", ["commit", "-q", "--allow-empty", "-m", "work"], { cwd: work }).status, 0);
    assert.equal(run("git", ["switch", "-c", "other"], { cwd: work }).status, 0);
    assert.equal(run("git", ["checkout", "-q", "bead"], { cwd: work }).status, 0);
    assert.equal(run("git", ["reset", "-q", "--hard"], { cwd: work }).status, 0);
    // The throwaway-branch commit that stands in for a stash, in the worktree.
    assert.equal(run("git", ["checkout", "-q", "-b", "wip"], { cwd: work }).status, 0);
    assert.equal(run("git", ["commit", "-q", "--allow-empty", "-m", "wip"], { cwd: work }).status, 0);
  });
});

test("a symlinked path to a shared checkout is still refused", () => {
  withRun(({ dir, run, policy }) => {
    const shared = join(dir, "ynm");
    mkdirSync(shared);
    run("git", ["init", "-q", "-b", "main", shared]);
    policy("shared-paths", `${shared}\n`);
    spawnSync("ln", ["-s", shared, join(dir, "link")]);
    assert.equal(run("git", ["checkout", "-b", "x"], { cwd: join(dir, "link") }).status, 1);
  });
});

test("the stub says so when it is installed under another name, or the log is not set", () => {
  withRun(({ dir, env }) => {
    copyFileSync(join(files, "seat-stub.sh"), join(dir, "other"));
    chmodSync(join(dir, "other"), 0o755);
    const res = spawnSync(join(dir, "other"), [], { env, encoding: "utf8" });
    assert.equal(res.status, 2);
    assert.match(res.stderr, /install me as gh, git or bd/);
    const noLog = spawnSync(join(env.EVAL_BIN, "gh"), ["pr", "list"], {
      env: { ...env, EVAL_STUB_LOG: "" },
      encoding: "utf8",
    });
    assert.notEqual(noLog.status, 0);
    assert.match(noLog.stderr, /EVAL_STUB_LOG is not set/);
  });
});

test("the stubs are one script, installed under three names", () => {
  const fixture = readFileSync(join(files, "seat-fixture.sh"), "utf8");
  assert.match(fixture, /for tool in gh git bd/);
  assert.match(readFileSync(join(files, "seat-stub.sh"), "utf8"), /^#!\/usr\/bin\/env bash/);
});

test(
  "the fixture lays out a Wheelhouse with sibling checkouts, and the stubs guard them",
  { skip: !hasBd && "bd is not installed" },
  () => {
    withRun(({ dir, run, calls, refused, env }) => {
      const setup = `
        set -euo pipefail
        . "$EVAL_FIXTURES/seat-fixture.sh"
        seat_world "$PWD/world" Dalglish McCoist=repo:ynh
        seat_forbid '^gh pr merge'
        seat_gh_answer pr view 'OPEN'
        install_seat_stubs
      `;
      const res = run("bash", ["-c", setup]);
      assert.equal(res.status, 0, res.stderr);
      const world = join(dir, "world");
      // The Wheelhouse, with its constitution, charters, roster and a real graph.
      const agents = readFileSync(join(world, "hq", "AGENTS.md"), "utf8");
      assert.match(agents, /Never change a shared checkout/);
      assert.match(agents, /`ynh`: `\.\.\/ynh`/);
      assert.match(readFileSync(join(world, "hq", "harnesses", "mccoist", "AGENTS.md"), "utf8"), /repo:ynh/);
      assert.ok(existsSync(join(world, "hq", "harnesses", "anderson", "AGENTS.md")));
      assert.ok(existsSync(join(world, "hq", ".beads")));
      // Siblings sit where the constitution says: ../ynh from hq.
      for (const repo of ["ynh", "ynm", "ynf", "ynr", "assistants", "homebrew-tap"]) {
        assert.ok(existsSync(join(world, "hq", "..", repo, ".git")), repo);
      }
      const shared = readFileSync(join(dir, ".eval", "shared-paths"), "utf8").split("\n").filter(Boolean);
      assert.equal(shared.length, 6);
      assert.ok(shared.includes(join(world, "ynh")));
      // The stubs are installed: they guard the siblings and refuse what the case forbids.
      assert.equal(run("git", ["checkout", "-b", "x"], { cwd: join(world, "ynh") }).status, 1);
      assert.equal(run("git", ["commit", "--allow-empty", "-m", "x"], { cwd: join(world, "ynm") }).status, 1);
      assert.equal(run("gh", ["pr", "merge", "5"]).status, 1);
      assert.equal(run("gh", ["pr", "view", "5"]).stdout, "OPEN\n");
      assert.equal(run("git", ["log", "--oneline"], { cwd: join(world, "hq") }).status, 0);
      assert.equal(run("bd", ["list"], { cwd: join(world, "hq") }).status, 0, "bd is the real one");
      assert.equal(refused().length, 3);
      assert.ok(calls().includes("gh pr merge 5"));
      assert.ok(env.PATH.startsWith(env.EVAL_BIN));
    }, { stubs: false });
  },
);
