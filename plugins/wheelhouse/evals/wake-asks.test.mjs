// The desk's wake lists every open ask (ask.sh show --all) with its kind, asker, answering seat and age,
// and says plainly when the asks can't be read. Other seats' wakes carry no asks section. Each case runs the
// real wake.sh and ask.sh in a throwaway Wheelhouse, with stand-ins for bd, ynm and gh on the path.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const wg = join(plugin, "skills", "work-graph", "scripts");
const wakeSrc = join(plugin, "skills", "wake", "scripts", "wake.sh");

const NOW = 1_800_000_000;
const iso = (secsAgo) => new Date((NOW - secsAgo) * 1000).toISOString();
const ASKS = [
  { id: "x-2", title: "Which branch?", status: "open", assignee: "marr", created_by: "albarn", labels: ["ask", "ask:question"], created_at: iso(3 * 3600), priority: 2 },
  { id: "x-1", title: "Wake May", status: "open", assignee: "eno", created_by: "hannett", labels: ["ask", "ask:request"], created_at: iso(3 * 86400), priority: 2 },
];

// asks: what `bd list --label ask` answers; listFails: bd list exits 1; noAskSh: ask.sh is not copied in; askShBroken: ask.sh prints nothing and fails.
function run(seat, { asks = ASKS, listFails = false, noAskSh = false, askShBroken = false } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-wake-asks-"));
  try {
    mkdirSync(join(dir, "scripts"));
    for (const [from, to] of [[wakeSrc, "wake.sh"], [join(wg, "memory.sh"), "memory.sh"], [join(wg, "wheelhouse-lib.sh"), "wheelhouse-lib.sh"], [join(wg, "inbox.sh"), "inbox.sh"]]) {
      writeFileSync(join(dir, "scripts", to), readFileSync(from));
    }
    if (askShBroken) writeFileSync(join(dir, "scripts", "ask.sh"), "#!/bin/bash\nexit 1\n");
    else if (!noAskSh) writeFileSync(join(dir, "scripts", "ask.sh"), readFileSync(join(wg, "ask.sh")));
    mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
    writeFileSync(
      join(dir, "skills", "roster", "assets", "roster.json"),
      JSON.stringify({
        seats: [
          { name: "Ynw", group: "desk", command: "ynw", harness: ".", mandate: "Talk." },
          { name: "Tess", group: "workers", command: "tess", harness: ".", mandate: "Build." },
        ],
        humans: [{ name: "Pat", command: "pat", default: true }],
      }),
    );
    mkdirSync(join(dir, "bin"));
    writeFileSync(join(dir, "asks.json"), JSON.stringify(asks));
    const stubs = {
      bd: `#!/bin/bash
case "$*" in
  *"list --label ask"*) ${listFails ? 'echo "dolt is down" >&2; exit 1' : `cat "${join(dir, "asks.json")}"`} ;;
  *"dep list"*) echo '[]' ;;
  *"dolt remote"*) echo '[]' ;;
  *) echo '[]' ;;
esac
`,
      ynm: "#!/bin/sh\necho '[]'\n",
      gh: "#!/bin/sh\nexit 1\n",
    };
    for (const [name, body] of Object.entries(stubs)) {
      writeFileSync(join(dir, "bin", name), body);
      chmodSync(join(dir, "bin", name), 0o755);
    }
    spawnSync("git", ["init", "-q"], { cwd: dir });
    const env = { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, ASK_NOW: String(NOW), WAKE_BD_SECS: "5", WAKE_ASK_SECS: "10", WAKE_INBOX_SECS: "10", WAKE_SYNC_SECS: "5", WAKE_YNM_SECS: "5" };
    const text = spawnSync("bash", [join(dir, "scripts", "wake.sh"), seat, "--format", "text", "--no-sync"], { cwd: dir, encoding: "utf8", timeout: 60000, env });
    const json = spawnSync("bash", [join(dir, "scripts", "wake.sh"), seat, "--no-sync"], { cwd: dir, encoding: "utf8", timeout: 60000, env });
    return { text, json: JSON.parse(json.stdout) };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("the desk's wake lists every open ask, oldest first, with kind, asker, answering seat and age", () => {
  const { text, json } = run("ynw");
  assert.equal(text.status, 0, text.stderr);
  assert.match(text.stdout, /## Asks between seats/);
  assert.match(text.stdout, /- Wake May \(x-1, request, asked by hannett, with eno, open 3d\)/);
  assert.match(text.stdout, /- Which branch\? \(x-2, question, asked by albarn, with marr, open 3h\)/);
  assert.ok(text.stdout.indexOf("x-1") < text.stdout.indexOf("x-2"), "oldest first");
  assert.equal(json.asks.count, 2);
  assert.deepEqual(json.asks.asks.map((a) => a.id), ["x-1", "x-2"]);
});

test("no open asks: the desk's wake says so plainly", () => {
  const { text, json } = run("ynw", { asks: [] });
  assert.match(text.stdout, /## Asks between seats\n\nNo open asks\./);
  assert.equal(json.asks.count, 0);
});

test("ask.sh failing to read bd: the wake says the asks could not be read, never 'no open asks'", () => {
  const { text, json } = run("ynw", { listFails: true });
  assert.equal(text.status, 0, text.stderr);
  assert.match(text.stdout, /The asks could not be read in full/);
  assert.match(text.stdout, /dolt is down/);
  assert.doesNotMatch(text.stdout, /No open asks/);
  assert.ok(json.asks.errors.length > 0);
});

test("ask.sh broken, or not copied in: the wake says so and carries on", () => {
  const broken = run("ynw", { askShBroken: true });
  assert.equal(broken.text.status, 0, broken.text.stderr);
  assert.match(broken.text.stdout, /The open asks could not be read: /);
  assert.ok(broken.json.asks.error);
  const missing = run("ynw", { noAskSh: true });
  assert.match(missing.text.stdout, /The open asks could not be read: no ask\.sh in the work-graph skill/);
  assert.doesNotMatch(missing.text.stdout, /No open asks/);
  assert.match(missing.text.stdout, /## Who you are/);
});

test("another seat's wake carries no asks section", () => {
  const { text, json } = run("tess");
  assert.doesNotMatch(text.stdout, /Asks between seats/);
  assert.equal(json.asks, null);
});
