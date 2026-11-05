// open-pr.sh opens a draft PR with the bead's tracker item and release. Each case runs the real
// script against stubs: bd answers `show` and `list` from a JSON file, gh answers `repo view` and
// `issue view` (the release command in tracker.json) and records `pr create`.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const script = join(plugin, "skills", "work-graph", "scripts", "open-pr.sh");

const bdStub = `#!/bin/sh
case "$1" in
  show) jq -c --arg id "$2" '[.[] | select(.id == $id)]' "$BD_STATE" | jq -e 'length > 0' >/dev/null || exit 1
        jq -c --arg id "$2" '[.[] | select(.id == $id)]' "$BD_STATE" ;;
  list) cat "$BD_STATE" ;;
esac
`;
const ghStub = `#!/bin/sh
printf '%s\\n' "$*" >> "$GH_LOG"
case "$1 $2" in
  "repo view") echo "$GH_REPO" ;;
  "issue view") printf '%s\\n' "$GH_MILESTONE" ;;
  "pr create") echo "https://github.com/$GH_REPO/pull/7" ;;
  *) echo "gh stub: unexpected $*" >&2; exit 1 ;;
esac
`;

const ISSUE = "https://github.com/eyelock/ynh/issues/680";
const github = {
  kind: "github",
  item: { name: "issue", pattern: "^https://github\\.com/[^/]+/[^/]+/issues/[0-9]+$" },
  release: { name: "milestone", read: "gh issue view {item} --json milestone --jq .milestone.title" },
};
const bead = (id, over = {}) => ({ id, status: "in_progress", labels: ["repo:ynh"], external_ref: ISSUE, ...over });

function harness({ tracker = github, beads = [bead("hq-1")], milestone = "v0.17.0" } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-openpr-"));
  mkdirSync(join(dir, "bin"));
  for (const [n, body] of [["bd", bdStub], ["gh", ghStub]]) {
    writeFileSync(join(dir, "bin", n), body);
    chmodSync(join(dir, "bin", n), 0o755);
  }
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
  };
  return {
    dir,
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

test("another tracker kind uses the generic adapter: the item in the body, no release flag", () => {
  const jira = {
    kind: "jira",
    item: { name: "ticket", pattern: "^[A-Z][A-Z0-9]+-[0-9]+$" },
    release: { name: "fixVersion", read: "echo 2.4 {item}" },
  };
  const h = harness({ tracker: jira, beads: [bead("hq-1", { external_ref: "PLAT-12" })] });
  const r = h.run();
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.json.release, "2.4 PLAT-12");
  assert.match(r.json.closing, /PLAT-12/);
  assert.doesNotMatch(h.log(), /--milestone/);
  h.done();
});

test("the item is never parsed as shell, even with no pattern to stop it", () => {
  const tracker = { kind: "linear", item: { name: "issue" }, release: { name: "milestone", read: "echo {item}" } };
  const evil = "x; touch PWNED";
  const h = harness({ tracker, beads: [bead("hq-1", { external_ref: evil })] });
  const r = h.run(["--bead", "hq-1", "--dry-run"]);
  assert.equal(r.json.release, evil);
  assert.equal(r.json.item, evil);
  assert.equal(existsSync(join(h.dir, "PWNED")), false);
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
  assert.equal(spawnSync("bash", [script], { encoding: "utf8" }).status, 1);
  h.done();
});
