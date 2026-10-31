// A seat's model comes from the roster: its own tier, else its group's default, mapped to a model
// per vendor with per-vendor overrides, by add-seat's model.sh; the starter-team templates carry
// the tiers (workers and watchers cheaper, designers, reviewers and dispatchers stronger); and
// the doctor warns about a seat with none. Each case runs the real scripts on a small roster.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const modelSh = join(plugin, "skills", "add-seat", "scripts", "model.sh");
const checkSh = join(plugin, "skills", "doctor", "scripts", "check.sh");
const team = join(plugin, "skills", "add-seat", "assets", "starter-team");

const seat = (command, group, extra = {}) => ({ name: command, group, command, harness: `harnesses/${command}`, mandate: "m", ...extra });

function withRoster(roster, fn) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-seat-model-"));
  try {
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
    fn(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const model = (dir, ...args) => spawnSync("bash", [modelSh, "--dir", dir, ...args], { encoding: "utf8" });

const roster = {
  models: {
    groups: { crew: "deep", workers: "fast" },
    tiers: { deep: { claude: "opus", codex: "big-model" } },
  },
  seats: [
    seat("okafor", "workers"),
    seat("gore", "crew"),
    seat("quick", "workers", { model: "balanced", models: { claude: "haiku" } }),
    seat("tharg", "standing", { model: "deep" }),
    seat("dredd", "standing"),
  ],
};

test("a seat takes its group's tier, its own tier, or a vendor override, and the plugin's table fills gaps", () => {
  withRoster(roster, (dir) => {
    assert.equal(model(dir, "--seat", "okafor").stdout.trim(), "sonnet");
    assert.equal(model(dir, "--seat", "gore").stdout.trim(), "opus");
    assert.equal(model(dir, "--seat", "tharg").stdout.trim(), "opus");
    assert.equal(model(dir, "--seat", "quick").stdout.trim(), "haiku");
    assert.equal(model(dir, "--seat", "gore", "--vendor", "codex").stdout.trim(), "big-model");
    assert.equal(model(dir, "--seat", "okafor", "--format", "flag").stdout.trim(), "--model=sonnet");
    assert.deepEqual(JSON.parse(model(dir, "--seat", "gore", "--format", "json").stdout), {
      seat: "gore",
      vendor: "claude",
      tier: "deep",
      model: "opus",
    });
  });
});

test("a seat with no model, no vendor mapping or no place in the roster exits 4", () => {
  withRoster(roster, (dir) => {
    for (const args of [["--seat", "dredd"], ["--seat", "okafor", "--vendor", "codex"], ["--seat", "nobody"]]) {
      const r = model(dir, ...args);
      assert.equal(r.status, 4, args.join(" "));
      assert.equal(r.stdout, "");
      assert.match(r.stderr, /no model for seat/);
    }
  });
});

test("the starter team puts workers and watchers on the cheaper tier, and designers, reviewers and dispatchers on the stronger", () => {
  const tier = Object.fromEntries(
    readdirSync(team).map((f) => [f.replace(/\.md$/, ""), /^model:\s*(\S+)$/m.exec(readFileSync(join(team, f), "utf8"))?.[1]]),
  );
  assert.deepEqual(tier, {
    "ci-watcher": "fast",
    designer: "deep",
    dispatcher: "deep",
    releaser: "fast",
    reviewer: "deep",
    "specialist-worker": "fast",
    worker: "fast",
  });
});

test("the doctor warns about a seat with no model, and not when every seat has one", () => {
  const find = (dir) => {
    const r = spawnSync("bash", [checkSh, "--dir", dir], { encoding: "utf8" });
    return JSON.parse(r.stdout).checks.find((c) => c.name === "seat models");
  };
  withRoster(roster, (dir) => {
    const c = find(dir);
    assert.equal(c.ok, false);
    assert.equal(c.level, "warn");
    assert.match(c.detail, /dredd/);
    assert.doesNotMatch(c.detail, /okafor|gore|quick|tharg/);
  });
  withRoster({ ...roster, seats: roster.seats.filter((s) => s.command !== "dredd") }, (dir) => {
    assert.equal(find(dir).ok, true);
  });
});
