// The patrol prints only what changed. patrol.sh reads each repository's pull requests, issues and
// CI with gh, compares them with the last run's snapshot, and prints the changes as a JSON list:
// [] when nothing changed, so a seat on a timer is woken only when there's news. Each case runs the
// real patrol.sh against a gh stub that answers from a JSON file the test rewrites between runs.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const patrolSh = join(plugin, "skills", "patrol", "scripts", "patrol.sh");

// gh: answers pr list, issue list, repo view, run list and api commits from $GH_STATE, logs each
// call to $GH_LOG, and fails for a repository named in $GH_FAIL.
const ghStub = `#!/bin/sh
printf '%s\\n' "$*" >> "$GH_LOG"
repo=""; prev=""
for a in "$@"; do
  [ "$prev" = -R ] && repo="$a"
  prev="$a"
done
[ "$1 $2" = "repo view" ] && repo="$3"
if [ -n "$repo" ] && [ "$repo" = "$GH_FAIL" ]; then echo "HTTP 502: Bad Gateway" >&2; exit 1; fi
case "$1 $2" in
  "pr list") jq -c --arg r "$repo" '.repos[$r].prs // []' "$GH_STATE" ;;
  "issue list") jq -c --arg r "$repo" '.repos[$r].issues // []' "$GH_STATE" ;;
  "repo view") jq -r --arg r "$repo" '.repos[$r].branch // "main"' "$GH_STATE" ;;
  "run list") jq -c --arg r "$repo" '.repos[$r].runs // []' "$GH_STATE" ;;
  api*) oid=\${2##*/}; jq -r --arg o "$oid" '.parents[$o] // 1' "$GH_STATE" ;;
  *) echo "gh stub: unexpected $*" >&2; exit 1 ;;
esac
`;

const R = "example/widget";
const pr = (number, over = {}) => ({
  number,
  title: `PR ${number}`,
  url: `https://github.com/${R}/pull/${number}`,
  state: "OPEN",
  isDraft: false,
  baseRefName: "develop",
  mergeStateStatus: "CLEAN",
  mergeCommit: null,
  statusCheckRollup: [{ __typename: "CheckRun", status: "COMPLETED", conclusion: "SUCCESS" }],
  ...over,
});
const issue = (number, over = {}) => ({
  number,
  title: `Issue ${number}`,
  url: `https://github.com/${R}/issues/${number}`,
  state: "OPEN",
  stateReason: null,
  ...over,
});
const red = [{ __typename: "CheckRun", status: "COMPLETED", conclusion: "FAILURE" }];
const run = (conclusion) => [
  { workflowName: "CI", status: "completed", conclusion, url: `https://github.com/${R}/actions/runs/1`, headSha: "a" },
];

function harness() {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-patrol-"));
  mkdirSync(join(dir, "bin"));
  writeFileSync(join(dir, "bin", "gh"), ghStub);
  chmodSync(join(dir, "bin", "gh"), 0o755);
  const wh = join(dir, "wh");
  mkdirSync(wh);
  const env = (extra = {}) => ({
    ...process.env,
    PATH: `${join(dir, "bin")}:${process.env.PATH}`,
    GH_STATE: join(dir, "state.json"),
    GH_LOG: join(dir, "gh.log"),
    GH_FAIL: "",
    WHEELHOUSE_REPOS: "",
    ...extra,
  });
  return {
    dir,
    wh,
    set: (state) => writeFileSync(join(dir, "state.json"), JSON.stringify(state)),
    patrol: (args = ["--repo", R], extra = {}) => {
      const out = spawnSync("bash", [patrolSh, ...args], { cwd: wh, encoding: "utf8", env: env(extra) });
      let json = null;
      try {
        json = JSON.parse(out.stdout);
      } catch {}
      return { ...out, json };
    },
    log: () => (existsSync(join(dir, "gh.log")) ? readFileSync(join(dir, "gh.log"), "utf8") : ""),
    done: () => rmSync(dir, { recursive: true, force: true }),
  };
}

const before = {
  repos: {
    [R]: {
      branch: "develop",
      prs: [
        pr(1),
        pr(2),
        pr(3),
        pr(4, { isDraft: true }),
        pr(5),
        pr(6),
        pr(7),
        pr(8, { statusCheckRollup: red }),
        pr(9, { state: "CLOSED" }),
        pr(10),
      ],
      issues: [issue(20), issue(21), issue(22, { state: "CLOSED", stateReason: "COMPLETED" })],
      runs: run("success"),
    },
  },
};

const after = {
  repos: {
    [R]: {
      branch: "develop",
      prs: [
        pr(1, { state: "MERGED", mergeCommit: { oid: "m1" } }),
        pr(2, { state: "MERGED", mergeCommit: { oid: "s2" } }),
        pr(3, { state: "CLOSED" }),
        pr(4),
        pr(5, { isDraft: true }),
        pr(6, { baseRefName: "main" }),
        pr(7, { mergeStateStatus: "DIRTY", statusCheckRollup: red }),
        pr(8),
        pr(9),
        pr(10),
        pr(11),
      ],
      issues: [issue(20, { state: "CLOSED", stateReason: "NOT_PLANNED" }), issue(21), issue(22), issue(23)],
      runs: run("failure"),
    },
  },
  parents: { m1: 2, s2: 1 },
};

test("first run: saves the snapshot, ignored by git, and prints []", () => {
  const h = harness();
  try {
    h.set(before);
    const first = h.patrol();
    assert.equal(first.status, 0, first.stderr);
    assert.deepEqual(first.json, []);
    assert.match(first.stderr, /first run/);
    assert.ok(existsSync(join(h.wh, ".wheelhouse", "patrol.json")));
    assert.equal(readFileSync(join(h.wh, ".wheelhouse", ".gitignore"), "utf8"), "*\n");
  } finally {
    h.done();
  }
});

test("nothing changed: [] and exit 0", () => {
  const h = harness();
  try {
    h.set(before);
    h.patrol();
    const again = h.patrol();
    assert.equal(again.status, 0, again.stderr);
    assert.deepEqual(again.json, []);
    assert.equal(again.stderr, "");
  } finally {
    h.done();
  }
});

test("every change kind, each once, with how each pull request was merged", () => {
  const h = harness();
  try {
    h.set(before);
    h.patrol();
    h.set(after);
    const out = h.patrol();
    assert.equal(out.status, 0, out.stderr);
    const got = Object.fromEntries(out.json.map((c) => [`${c.kind} ${c.number ?? c.branch}`, c]));
    assert.deepEqual(Object.keys(got).sort(), [
      "ci-red develop",
      "issue-closed 20",
      "issue-opened 23",
      "issue-reopened 22",
      "pr-ci-green 8",
      "pr-ci-red 7",
      "pr-closed 3",
      "pr-dirty 7",
      "pr-draft 5",
      "pr-merged 1",
      "pr-merged 2",
      "pr-opened 11",
      "pr-ready 4",
      "pr-reopened 9",
      "pr-retargeted 6",
    ]);
    assert.equal(got["pr-merged 1"].method, "merge");
    assert.equal(got["pr-merged 2"].method, "squash");
    assert.equal(got["pr-merged 1"].mergeCommit, undefined);
    assert.deepEqual([got["pr-retargeted 6"].from, got["pr-retargeted 6"].to], ["develop", "main"]);
    assert.equal(got["issue-closed 20"].reason, "NOT_PLANNED");
    assert.equal(got["pr-opened 11"].url, `https://github.com/${R}/pull/11`);
    assert.equal(got["ci-red develop"].repo, R);

    // The snapshot moved on: the same state again is no news, and CI green again is.
    assert.deepEqual(h.patrol().json, []);
    h.set({ ...after, repos: { [R]: { ...after.repos[R], runs: run("success") } } });
    assert.deepEqual(
      h.patrol().json.map((c) => c.kind),
      ["ci-green"],
    );
  } finally {
    h.done();
  }
});

test("--dry-run prints the changes but leaves the snapshot, so the next run sees them too", () => {
  const h = harness();
  try {
    h.set(before);
    h.patrol();
    h.set(after);
    const peek = h.patrol(["--repo", R, "--dry-run"]);
    assert.equal(peek.status, 0, peek.stderr);
    assert.equal(peek.json.length, 15);
    assert.equal(h.patrol().json.length, 15);
    assert.deepEqual(h.patrol(["--repo", R, "--dry-run"]).json, []);
  } finally {
    h.done();
  }
});

test("a repository gh can't read: an error, exit 3, and its changes are kept for the next run", () => {
  const h = harness();
  try {
    h.set(before);
    h.patrol();
    h.set(after);
    const down = h.patrol(["--repo", R], { GH_FAIL: R });
    assert.equal(down.status, 3);
    assert.deepEqual(down.json, [{ kind: "error", repo: R, detail: "gh pr list: HTTP 502: Bad Gateway" }]);
    const back = h.patrol();
    assert.equal(back.status, 0, back.stderr);
    assert.equal(back.json.length, 15, "what happened while gh was down is reported once it's back");
  } finally {
    h.done();
  }
});

test("--snapshot keeps the snapshot where it's told, and a new repository starts as a baseline", () => {
  const h = harness();
  try {
    const snap = join(h.dir, "seat-scratch", "patrol.json");
    mkdirSync(dirname(snap));
    h.set(before);
    h.patrol(["--repo", R, "--snapshot", snap]);
    assert.ok(existsSync(snap));
    assert.ok(!existsSync(join(h.wh, ".wheelhouse")));
    h.set({ repos: { ...before.repos, "example/gadget": { prs: [pr(1)], issues: [], runs: [] } } });
    const out = h.patrol(["--repo", R, "--repo", "example/gadget", "--snapshot", snap]);
    assert.equal(out.status, 0, out.stderr);
    assert.deepEqual(out.json, [], "a repository the last run never saw reports nothing");
    assert.deepEqual(Object.keys(JSON.parse(readFileSync(snap, "utf8")).repos).sort(), ["example/gadget", R]);
  } finally {
    h.done();
  }
});

test("without --repo, the repositories are the Wheelhouse's own and those under What it reaches", () => {
  const h = harness();
  try {
    const git = (cwd, ...args) => spawnSync("git", args, { cwd, encoding: "utf8" });
    git(h.wh, "init", "-q");
    git(h.wh, "remote", "add", "origin", "git@github.com:example/hq.git");
    for (const [name, url] of [
      ["api", "https://github.com/example/api.git"],
      ["docs", "https://github.com/example/docs"],
    ]) {
      mkdirSync(join(h.dir, name));
      git(join(h.dir, name), "init", "-q");
      git(join(h.dir, name), "remote", "add", "origin", url);
    }
    writeFileSync(
      join(h.wh, "AGENTS.md"),
      "# hq\n\n## What it reaches\n\nRepositories: `api`: `../api`, `docs`: `../docs`.\n\n## Rules\n\n`../elsewhere`\n",
    );
    h.set({ repos: {} });
    const out = h.patrol([]);
    assert.equal(out.status, 0, out.stderr);
    const read = [...h.log().matchAll(/^pr list -R (\S+)/gm)].map((m) => m[1]);
    assert.deepEqual(read, ["example/hq", "example/api", "example/docs"]);
  } finally {
    h.done();
  }
});

test("bad arguments are refused", () => {
  const h = harness();
  try {
    assert.equal(h.patrol(["--repo", "not a repo"]).status, 1);
    assert.equal(h.patrol(["--repo", R, "--limit", "0"]).status, 1);
    assert.equal(h.patrol(["--bogus"]).status, 1);
  } finally {
    h.done();
  }
});
