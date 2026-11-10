// open-pr.sh opens a draft PR with the bead's tracker item and release. Each case runs the real
// script against stubs: bd answers `show` and `list` from a JSON file, gh answers `repo view` and
// `issue view` (what the GitHub adapter calls for a release or a state) and records `pr create`.
// The scripts are copied into each case's folder, so a case can add an adapter of its own.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const scriptsDir = join(plugin, "skills", "work-graph", "scripts");

const bdStub = `#!/bin/sh
case "$1" in
  show) jq -c --arg id "$2" '[.[] | select(.id == $id)]' "$BD_STATE" | jq -e 'length > 0' >/dev/null || exit 1
        jq -c --arg id "$2" '[.[] | select(.id == $id)]' "$BD_STATE" ;;
  note) [ -z "$BD_NOTE_FAIL" ] || exit 1; printf '%s\\n' "$*" >> "$BD_NOTE_LOG" ;;
  list) [ -z "$BD_LIST_FAIL" ] || { echo "bd: list failed" >&2; exit 1; }; cat "$BD_STATE" ;;
esac
`;
const ghStub = `#!/bin/sh
printf '%s\\n' "$*" >> "$GH_LOG"
case "$1 $2" in
  "repo view") echo "$GH_REPO" ;;
  "issue view") case "$*" in *"--json state"*) echo "$GH_STATE" ;; *) printf '%s\\n' "$GH_MILESTONE" ;; esac ;;
  "pr create") echo "https://github.com/$GH_REPO/pull/7" ;;
  *) echo "gh stub: unexpected $*" >&2; exit 1 ;;
esac
`;

const ISSUE = "https://github.com/eyelock/ynh/issues/680";
const github = {
  kind: "github",
  item: { name: "issue", pattern: "^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+$" },
  release: { name: "milestone" },
};
const bead = (id, over = {}) => ({ id, status: "in_progress", labels: ["repo:ynh"], external_ref: ISSUE, ...over });

function harness({ tracker = github, beads = [bead("hq-1")], milestone = "v0.17.0", listFails = false, noteFails = false, adapters = {} } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-openpr-"));
  mkdirSync(join(dir, "bin"));
  for (const [n, body] of [["bd", bdStub], ["gh", ghStub]]) {
    writeFileSync(join(dir, "bin", n), body);
    chmodSync(join(dir, "bin", n), 0o755);
  }
  const scripts = join(dir, "scripts");
  cpSync(scriptsDir, scripts, { recursive: true });
  cpSync(join(plugin, "lib", "wheelhouse-lib.sh"), join(scripts, "wheelhouse-lib.sh"));
  for (const [kind, body] of Object.entries(adapters)) writeFileSync(join(scripts, `tracker-${kind}.sh`), body);
  const script = join(scripts, "open-pr.sh");
  const wh = join(dir, "wh");
  mkdirSync(join(wh, ".beads"), { recursive: true });
  if (tracker) writeFileSync(join(wh, "tracker.json"), JSON.stringify(tracker));
  writeFileSync(join(dir, "beads.json"), JSON.stringify(beads));
  writeFileSync(join(dir, "body.md"), "**Albarn** · ynw build seat\n\nDoes the thing.\n");
  const env = {
    ...process.env,
    PATH: `${join(dir, "bin")}:${process.env.PATH}`,
    BD_STATE: join(dir, "beads.json"),
    GH_LOG: join(dir, "gh.log"),
    GH_REPO: "eyelock/ynh",
    GH_MILESTONE: milestone,
    GH_STATE: "OPEN",
    BD_LIST_FAIL: listFails ? "1" : "",
    BD_NOTE_LOG: join(dir, "notes.log"),
    BD_NOTE_FAIL: noteFails ? "1" : "",
  };
  return {
    dir,
    scripts,
    run: (args = ["--bead", "hq-1"]) => {
      const out = spawnSync(
        "bash",
        [script, "--dir", wh, "--title", "feat: x", "--body-file", join(dir, "body.md"), ...args],
        { cwd: dir, encoding: "utf8", env },
      );
      let json = null;
      try {
        json = JSON.parse(out.stdout);
      } catch {}
      return { ...out, json };
    },
    notes: () => (existsSync(join(dir, "notes.log")) ? readFileSync(join(dir, "notes.log"), "utf8") : ""),
    log: () => (existsSync(join(dir, "gh.log")) ? readFileSync(join(dir, "gh.log"), "utf8") : ""),
    done: () => rmSync(dir, { recursive: true, force: true }),
  };
}

test("the last open bead on an item closes it, and the PR gets the milestone", () => {
  const h = harness();
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.url, "https://github.com/eyelock/ynh/pull/7");
  assert.equal(r.json.release, "v0.17.0");
  assert.equal(r.json.closing, "Closes #680");
  const create = h.log();
  assert.match(create, /--draft/);
  assert.match(create, /--milestone v0\.17\.0/);
  assert.match(create, /Closes #680/);
  assert.match(create, /Albarn/);
  h.done();
});

test("another open bead on the item means Part of, not Closes", () => {
  const h = harness({ beads: [bead("hq-1"), bead("hq-2", { status: "open" }), bead("hq-3", { status: "closed" })] });
  const r = h.run();
  assert.equal(r.json.closing, "Part of #680");
  h.done();
});

test("an issue in another repository is named in full", () => {
  const h = harness();
  const r = h.run(["--bead", "hq-1", "--repo", "eyelock/assistants"]);
  assert.equal(r.json.closing, "Closes eyelock/ynh#680");
  h.done();
});

test("a bead whose external_ref is a pull request URL is a review fix: a dry run reports it, a real run opens no PR", () => {
  const PR = "https://github.com/eyelock/ynh/pull/700";
  const h = harness({ beads: [bead("hq-1", { external_ref: PR })] });
  const dry = h.run(["--bead", "hq-1", "--dry-run"]);
  assert.equal(dry.status, 0, dry.stderr);
  assert.equal(dry.json.review_fix, true);
  assert.equal(dry.json.pr, PR);
  const real = h.run();
  assert.equal(real.status, 1);
  assert.match(real.json.refused, /review fix/);
  assert.doesNotMatch(h.log(), /pr create/);
  h.done();
});

test("an issue URL is not a review fix", () => {
  const h = harness();
  const r = h.run(["--bead", "hq-1", "--dry-run"]);
  assert.equal(r.status, 0, r.stderr);
  assert.notEqual(r.json.review_fix, true);
  h.done();
});

test("refuses a build bead with no tracker item, and says why", () => {
  const h = harness({ beads: [bead("hq-1", { external_ref: null })] });
  const r = h.run();
  assert.equal(r.status, 1);
  assert.match(r.json.refused, /no external_ref/);
  assert.match(r.json.refused, /housekeeping/);
  assert.doesNotMatch(h.log(), /pr create/);
  h.done();
});

test("a housekeeping bead with no item opens a PR without a release", () => {
  const h = harness({ beads: [bead("hq-1", { external_ref: null, labels: ["housekeeping"] })] });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.release, "");
  assert.doesNotMatch(h.log(), /--milestone/);
  assert.match(h.log(), /pr create --draft/);
  h.done();
});

test("refuses a reference that does not look like an item, and an item with no release", () => {
  let h = harness({ beads: [bead("hq-1", { external_ref: "PLAT-12" })] });
  let r = h.run();
  assert.equal(r.status, 1);
  assert.match(r.json.refused, /does not look like/);
  h.done();
  h = harness({ milestone: "" });
  r = h.run();
  assert.equal(r.status, 1);
  assert.match(r.json.refused, /no milestone/);
  assert.doesNotMatch(h.log(), /pr create/);
  h.done();
});

test("kind none, or no config, still opens PRs", () => {
  for (const tracker of [{ kind: "none" }, null]) {
    const h = harness({ tracker, beads: [bead("hq-1", { external_ref: null })] });
    const r = h.run();
    assert.equal(r.status, 0, r.stderr);
    assert.match(h.log(), /pr create --draft/);
    assert.doesNotMatch(h.log(), /--milestone|Closes|Part of/);
    h.done();
  }
});

const jiraAdapter = `#!/usr/bin/env bash
case "$1" in
  canon) echo "$2" ;;
  release) echo "2.4" ;;
  closing) echo "Jira: $2" ;;
  pr-flags) ;;
esac
`;
const jira = {
  kind: "jira",
  item: { name: "ticket", pattern: "^[A-Z][A-Z0-9]+-[0-9]+$" },
  release: { name: "fixVersion" },
};

test("another tracker kind works through an adapter of its own", () => {
  const h = harness({ tracker: jira, beads: [bead("hq-1", { external_ref: "PLAT-12" })], adapters: { jira: jiraAdapter } });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.release, "2.4");
  assert.equal(r.json.closing, "Jira: PLAT-12");
  assert.doesNotMatch(h.log(), /--milestone/);
  h.done();
});

test("a kind with no adapter of its own cannot read a release: a fault, nothing opened", () => {
  const h = harness({ tracker: jira, beads: [bead("hq-1", { external_ref: "PLAT-12" })] });
  const r = h.run();
  assert.equal(r.status, 3);
  assert.match(r.stderr, /could not read the release/);
  assert.match(r.stderr, /add tracker-<kind>\.sh/);
  assert.doesNotMatch(h.log(), /pr create/);
  h.done();
});

test("a hostile reference is refused before any command runs", () => {
  const evil = "https://github.com/a;touch${IFS}PWNED;/b/issues/1";
  const h = harness({ beads: [bead("hq-1", { external_ref: evil })] });
  const r = h.run();
  assert.equal(r.status, 1);
  assert.match(r.json.refused, /does not look like/);
  assert.equal(existsSync(join(h.dir, "PWNED")), false);
  assert.doesNotMatch(h.log(), /issue view|pr create/);
  h.done();
});

test("nothing in tracker.json is run: a command-looking field is ignored", () => {
  const tracker = { ...github, release: { name: "milestone", read: "touch PWNED" }, state: { read: "touch PWNED" } };
  const h = harness({ tracker });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(existsSync(join(h.dir, "PWNED")), false);
  h.done();
});

test("the GitHub adapter reads a release and a state with gh, and refuses anything but an issue URL", () => {
  const h = harness();
  const adapter = join(h.scripts, "tracker-github.sh");
  const env = { ...process.env, PATH: `${join(h.dir, "bin")}:${process.env.PATH}`, GH_LOG: join(h.dir, "gh.log"), GH_MILESTONE: "v1.2", GH_STATE: "CLOSED" };
  const call = (...a) => spawnSync("bash", [adapter, ...a], { encoding: "utf8", env });
  assert.equal(call("release", ISSUE).stdout.trim(), "v1.2");
  assert.equal(call("state", ISSUE).stdout.trim(), "closed");
  assert.equal(call("release", ISSUE).status, 0);
  const evil = call("release", "https://github.com/a;touch${IFS}PWNED;/b/issues/1");
  assert.equal(evil.status, 1);
  assert.equal(existsSync(join(h.dir, "PWNED")), false);
  assert.equal(call("state", "owner/repo#1").status, 1);
  // gh failing is a fault (exit 3) for both, whatever exit code gh itself gave.
  const bad = join(h.dir, "badbin");
  mkdirSync(bad);
  writeFileSync(join(bad, "gh"), "#!/bin/sh\nexit 4\n");
  chmodSync(join(bad, "gh"), 0o755);
  const broken = (...a) => spawnSync("bash", [adapter, ...a], { encoding: "utf8", env: { ...env, PATH: `${bad}:${env.PATH}` } });
  assert.equal(broken("release", ISSUE).status, 3);
  assert.equal(broken("state", ISSUE).status, 3);
  h.done();
});

test("a tracker config with no item.pattern is a fault, and runs nothing", () => {
  const tracker = { ...github, item: { name: "issue" } };
  const h = harness({ tracker });
  const r = h.run();
  assert.equal(r.status, 3);
  assert.match(r.stderr, /item\.pattern/);
  assert.doesNotMatch(h.log(), /issue view|pr create/);
  h.done();
});

test("--dry-run opens nothing, and bad args and unknown beads fail", () => {
  const h = harness();
  const r = h.run(["--bead", "hq-1", "--dry-run"]);
  assert.equal(r.status, 0);
  assert.equal(r.json.dry_run, true);
  assert.ok(r.json.gh.includes("--milestone"));
  assert.doesNotMatch(h.log(), /pr create/);
  assert.equal(h.run(["--bead", "hq-9"]).status, 2);
  assert.equal(spawnSync("bash", [join(scriptsDir, "open-pr.sh")], { encoding: "utf8" }).status, 1);
  h.done();
});

test("--dry-run needs no title, and names the item, release and relation a dispatch note quotes", () => {
  const h = harness({ beads: [bead("hq-1"), bead("hq-2", { status: "open" })] });
  const run = (id) => {
    const out = spawnSync("bash", [join(h.scripts, "open-pr.sh"), "--dir", join(h.dir, "wh"), "--bead", id, "--dry-run"], {
      cwd: h.dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(h.dir, "bin")}:${process.env.PATH}`, BD_STATE: join(h.dir, "beads.json"), GH_LOG: join(h.dir, "gh.log"), GH_REPO: "eyelock/ynh", GH_MILESTONE: "v0.17.0" },
    });
    return JSON.parse(out.stdout);
  };
  const a = run("hq-1");
  assert.deepEqual([a.item, a.item_name, a.release, a.release_name, a.relation], [ISSUE, "issue", "v0.17.0", "milestone", "part-of"]);
  h.done();
});

test("a sibling bead written in another case or the short form still counts as the same item", () => {
  for (const sibling of ["https://github.com/Eyelock/ynh/issues/680", "eyelock/ynh#680", "EyeLock/YNH#680"]) {
    const h = harness({ beads: [bead("hq-1"), bead("hq-2", { status: "open", external_ref: sibling })] });
    assert.equal(h.run().json.closing, "Part of #680", sibling);
    h.done();
  }
  const h = harness({ beads: [bead("hq-1"), bead("hq-2", { status: "open", external_ref: "eyelock/ynh#681" })] });
  assert.equal(h.run().json.closing, "Closes #680");
  h.done();
});

test("a kind that is not a plain word is a fault, never a file path", () => {
  const h = harness({ tracker: { ...github, kind: "../../evil" } });
  const r = h.run();
  assert.equal(r.status, 3);
  assert.match(r.stderr, /kind must be/);
  h.done();
});

test("when bd list fails it is a fault: exit 3, nothing opened, and never Closes", () => {
  const h = harness({
    beads: [bead("hq-1"), bead("hq-2", { status: "open" })],
    listFails: true,
  });
  const r = h.run();
  assert.equal(r.status, 3);
  assert.match(r.stderr, /bd list failed/);
  assert.doesNotMatch(r.stdout, /Closes/);
  assert.doesNotMatch(h.log(), /pr create/);
  h.done();
});

// exempt_repos: a bead whose repo: label is on the list needs no issue, and its PR opens with no
// issue, no closing link and no milestone; a bead in any other repository is unchanged.
const exemptGithub = { ...github, exempt_repos: ["hq"] };

test("a bead in an exempt repository opens with no item, no Closes line and no milestone, even with no external_ref", () => {
  const h = harness({ tracker: exemptGithub, beads: [bead("hq-1", { labels: ["repo:hq"], external_ref: null })] });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.exempt, true);
  assert.equal(r.json.item, "");
  assert.equal(r.json.release, "");
  assert.equal(r.json.closing, "");
  assert.match(h.log(), /pr create --draft/);
  assert.doesNotMatch(h.log(), /--milestone|Closes|Part of/);
  h.done();
});

test("an open bead in an exempt repository on the same item is no sibling: Closes stays Closes", () => {
  const h = harness({
    tracker: exemptGithub,
    beads: [bead("a-1"), bead("hq-2", { status: "open", labels: ["repo:hq"] })],
  });
  const r = h.run(["--bead", "a-1"]);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.relation, "closes");
  assert.equal(r.json.closing, "Closes #680");
  h.done();
});

test("an open bead in a non-exempt repository on the same item still means Part of", () => {
  const h = harness({ tracker: exemptGithub, beads: [bead("a-1"), bead("b-2", { status: "open" })] });
  assert.equal(h.run(["--bead", "a-1"]).json.closing, "Part of #680");
  h.done();
});

test("an exempt bead's external_ref is ignored: no closing link, and the tracker is not asked", () => {
  const h = harness({ tracker: exemptGithub, beads: [bead("hq-1", { labels: ["repo:hq"] })] });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.exempt, true);
  assert.doesNotMatch(h.log(), /issue view|--milestone|Closes/);
  h.done();
});

test("--dry-run on an exempt bead says exempt, with no tracker line to quote", () => {
  const h = harness({ tracker: exemptGithub, beads: [bead("hq-1", { labels: ["repo:hq"], external_ref: null })] });
  const r = h.run(["--bead", "hq-1", "--dry-run"]);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.dry_run, true);
  assert.equal(r.json.exempt, true);
  assert.equal(r.json.item, "");
  assert.equal(r.json.relation, "");
  h.done();
});

test("a bead in a repository not on the list is not exempt: it still needs its issue and gets its milestone", () => {
  const none = harness({ tracker: exemptGithub, beads: [bead("hq-1", { external_ref: null })] });
  const refused = none.run();
  assert.equal(refused.status, 1);
  assert.match(refused.json.refused, /no external_ref/);
  assert.doesNotMatch(none.log(), /pr create/);
  none.done();

  const h = harness({ tracker: exemptGithub });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.exempt, false);
  assert.equal(r.json.closing, "Closes #680");
  assert.match(h.log(), /--milestone v0\.17\.0/);
  h.done();
});

test("a bead with an exempt repo label and another is exempt only by the one on the list", () => {
  const h = harness({ tracker: exemptGithub, beads: [bead("hq-1", { labels: ["repo:ynh", "repo:hq"], external_ref: null })] });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.exempt, true);
  h.done();
});

test("an exempt_repos that is not a list of strings is a fault, never nothing exempt", () => {
  for (const bad of ["hq", [1], { hq: true }]) {
    const h = harness({ tracker: { ...github, exempt_repos: bad }, beads: [bead("hq-1", { labels: ["repo:hq"], external_ref: null })] });
    const r = h.run();
    assert.equal(r.status, 3, JSON.stringify(bad));
    assert.match(r.stderr, /exempt_repos must be a list/);
    assert.doesNotMatch(h.log(), /pr create/);
    h.done();
  }
});

test("exemption holds for another tracker kind, without calling its adapter", () => {
  const h = harness({
    tracker: { ...jira, exempt_repos: ["hq"] },
    beads: [bead("hq-1", { labels: ["repo:hq"], external_ref: null })],
    adapters: { jira: "#!/usr/bin/env bash\necho adapter-called >> \"$GH_LOG\"\n" },
  });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.exempt, true);
  assert.doesNotMatch(h.log(), /adapter-called/);
  h.done();
});

test("the PR's URL is noted on the bead as 'PR: <url>', and a --dry-run notes nothing", () => {
  const h = harness();
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(h.notes().trim(), "note hq-1 PR: https://github.com/eyelock/ynh/pull/7");
  const d = harness();
  assert.equal(d.run(["--bead", "hq-1", "--dry-run"]).status, 0);
  assert.equal(d.notes(), "");
  h.done();
  d.done();
});

test("an exempt bead's PR is noted too, and a failed note warns but keeps the PR", () => {
  const h = harness({ noteFails: true });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.url, "https://github.com/eyelock/ynh/pull/7");
  assert.match(r.stderr, /could not note it on hq-1/);
  h.done();
});

// A repository whose local branch tracks a remote branch of another name, as when a seat pushes
// another seat's branch from its own worktree.
function repoTracking(dir, local, remoteBranch) {
  const sh = (cwd, ...a) => spawnSync("git", a, { cwd, encoding: "utf8" });
  const origin = join(dir, "origin.git");
  const work = join(dir, "work");
  mkdirSync(work);
  sh(dir, "init", "-q", "--bare", origin);
  sh(work, "init", "-q", "-b", "main");
  sh(work, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "x");
  sh(work, "remote", "add", "origin", origin);
  sh(work, "checkout", "-q", "-b", local);
  sh(work, "push", "-q", "origin", `${local}:${remoteBranch}`);
  sh(work, "branch", `--set-upstream-to=origin/${remoteBranch}`);
  return work;
}

function runIn(h, cwd, args) {
  return spawnSync("bash", [join(h.scripts, "open-pr.sh"), "--dir", join(h.dir, "wh"), ...args], {
    cwd,
    encoding: "utf8",
    env: { ...process.env, PATH: `${join(h.dir, "bin")}:${process.env.PATH}`, BD_STATE: join(h.dir, "beads.json"), GH_LOG: join(h.dir, "gh.log"), GH_REPO: "eyelock/ynh", GH_MILESTONE: "v0.17.0", GH_STATE: "OPEN", BD_NOTE_LOG: join(h.dir, "notes.log") },
  });
}

test("a local branch tracking a differently named remote branch opens from the remote's name", () => {
  const h = harness();
  const work = repoTracking(h.dir, "local-name", "page/their-branch");
  const r = runIn(h, work, ["--bead", "hq-1", "--title", "feat: x"]);
  assert.equal(r.status, 0, r.stderr);
  assert.match(h.log(), /--head page\/their-branch/);
  h.done();
});

test("matching branch names and an explicit --head", () => {
  const h = harness();
  const work = repoTracking(h.dir, "same", "same");
  assert.equal(runIn(h, work, ["--bead", "hq-1", "--title", "feat: x"]).status, 0);
  assert.doesNotMatch(h.log(), /--head/);
  assert.equal(runIn(h, work, ["--bead", "hq-1", "--title", "feat: x", "--head", "other"]).status, 0);
  assert.match(h.log(), /--head other/);
  h.done();
});

test("outside a repository there is no --head, and the title defaults to the bead's", () => {
  const h = harness({ beads: [bead("hq-1", { title: "the bead title" })] });
  const r = runIn(h, h.dir, ["--bead", "hq-1"]);
  assert.equal(r.status, 0, r.stderr);
  assert.doesNotMatch(h.log(), /--head/);
  assert.match(h.log(), /--title the bead title/);
  h.done();
});
