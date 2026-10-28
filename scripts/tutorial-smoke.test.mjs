// The tutorial runner finds the steps a person would paste, in order, and
// rewrites the sandbox so a run never touches the one a person is using.
// These tests need no tools: they check the parsing, not the tutorials.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { marker, optIn, script, steps } from "./tutorial-smoke.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

const tutorial = `<!-- tutorial: test sandbox=/tmp/demo -->

# Demo

## Set up

\`\`\`bash
mkdir -p /tmp/demo/a
\`\`\`

Expected: no output.

\`\`\`text
not a step
\`\`\`

## Optional

<!-- tutorial: skip unless DEMO_KEY -->
\`\`\`bash
echo "needs a key"
\`\`\`

## Clean up

\`\`\`bash
rm -rf /tmp/demo
\`\`\`
`;

test("a tutorial opts in with its first line, naming its sandbox", () => {
  assert.equal(optIn(tutorial), "/tmp/demo");
  assert.equal(optIn("# A tutorial\n\n<!-- tutorial: test -->\n"), null);
  assert.equal(optIn("<!-- tutorial: test -->\n"), "");
  assert.deepEqual(marker("<!-- tutorial: test sandbox=/tmp/x checkout=REPO_CHECKOUT -->\n"), {
    sandbox: "/tmp/x",
    checkout: "REPO_CHECKOUT",
  });
});

test("steps are the bash blocks in order, with their headings and skip conditions", () => {
  assert.deepEqual(steps(tutorial), [
    { heading: "Set up", skipUnless: null, skipIf: null, script: "mkdir -p /tmp/demo/a" },
    { heading: "Optional", skipUnless: "DEMO_KEY", skipIf: null, script: 'echo "needs a key"' },
    { heading: "Clean up", skipUnless: null, skipIf: null, script: "rm -rf /tmp/demo" },
  ]);
});

test("the script rewrites the sandbox and leaves out skipped steps", () => {
  const s = script(steps(tutorial), [["/tmp/demo", "/tmp/run-1"]], {});
  assert.match(s, /^set -e\n/);
  assert.match(s, /mkdir -p \/tmp\/run-1\/a/);
  assert.match(s, /rm -rf \/tmp\/run-1/);
  assert.doesNotMatch(s, /\/tmp\/demo/);
  assert.doesNotMatch(s, /needs a key/);
  assert.match(s, /::step 1/);
  assert.match(s, /::step 3/);
  assert.doesNotMatch(s, /::step 2/);
});

test("skip if runs a step only while its variable is unset", () => {
  const list = [
    { heading: "", skipUnless: null, skipIf: "RUN_MODEL", script: "echo by-hand" },
    { heading: "", skipUnless: "RUN_MODEL", skipIf: null, script: "echo with-a-model" },
  ];
  assert.match(script(list, [], {}), /by-hand/);
  assert.doesNotMatch(script(list, [], {}), /with-a-model/);
  assert.match(script(list, [], { RUN_MODEL: "1" }), /with-a-model/);
  assert.doesNotMatch(script(list, [], { RUN_MODEL: "1" }), /by-hand/);
});

test("a skipped step runs when its variable is set", () => {
  const s = script(steps(tutorial), [["/tmp/demo", "/tmp/run-1"]], { DEMO_KEY: "1" });
  assert.match(s, /needs a key/);
});

test("rewrites apply in order, so a repository's .git URL goes before its bare URL", () => {
  const list = [
    { heading: "", skipUnless: null, script: "git clone https://x/r.git && echo https://x/r" },
  ];
  const s = script(
    list,
    [
      ["https://x/r.git", "file:///snap"],
      ["https://x/r", "file:///snap"],
    ],
    {},
  );
  assert.match(s, /git clone file:\/\/\/snap && echo file:\/\/\/snap/);
});

test("every opted-in tutorial has a sandbox and at least one step", () => {
  const path = join(root, "docs", "build", "tutorials", "build-a-wheelhouse.md");
  const markdown = readFileSync(path, "utf8");
  assert.equal(optIn(markdown), "/tmp/wheelhouse-tutorial");
  assert.ok(steps(markdown).length > 10);
});

test("the runner refuses a tutorial that has not opted in, and explains --help", () => {
  const runner = join(root, "scripts", "tutorial-smoke.mjs");
  const notOptedIn = join(root, "docs", "build", "tutorials", "write-a-skill-with-evals.md");
  assert.equal(spawnSync("node", [runner, notOptedIn], { encoding: "utf8" }).status, 1);
  assert.equal(spawnSync("node", [runner, join(root, "nope.md")], { encoding: "utf8" }).status, 2);
  const help = spawnSync("node", [runner, "--help"], { encoding: "utf8" });
  assert.equal(help.status, 0);
  assert.match(help.stdout, /Usage: node scripts\/tutorial-smoke\.mjs/);
});
