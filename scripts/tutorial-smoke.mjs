#!/usr/bin/env node
// Runs a tutorial as a test: every ```bash block, in order, in one shell,
// failing on the first block that exits non-zero. It checks nothing about the
// output; a model reading the tutorial does that. It exists so a renamed flag
// or a broken command is caught for free, before anyone walks through it.
//
// A tutorial opts in with `<!-- tutorial: test sandbox=<path> -->` on its first
// line. Every literal <path> in its blocks is rewritten to a fresh temporary
// directory, so runs never touch the sandbox a person is using and can
// overlap. A block whose fence follows `<!-- tutorial: skip unless VAR -->`
// runs only when VAR is set; one after `<!-- tutorial: skip if VAR -->` runs
// only when it isn't. Together they give a step two paths, such as asking a
// seat (a model run) or doing by hand what the seat would do.
//
// A tutorial that can run against a checkout of this repository, rather than
// the published one, names the variable it reads the checkout's path from with
// `checkout=<VAR>` in the same marker. The runner sets <VAR> to the checkout it
// runs from, so the tutorial's own developer steps switch on and it tests the
// working tree, uncommitted changes included. Set TUTORIAL_PUBLISHED=1 to run
// it as a reader would, against the published repository.
//
// Output: JSON on stdout, one entry per tutorial: {tutorial, ok, steps, ran,
// skipped, failed: {step, heading, exit, output} | null}. Diagnostics on stderr.
// Exit codes: 0 every tutorial passed, 1 bad args, 2 tutorial not found,
// 3 a step failed.

import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const OPT_IN = /^<!--\s*tutorial:\s*test((?:\s+[a-z]+=\S+)*)\s*-->/;
const SKIP = /^<!--\s*tutorial:\s*skip (unless|if)\s+([A-Z_][A-Z0-9_]*)\s*-->\s*$/;

const USAGE = `Usage: node scripts/tutorial-smoke.mjs [tutorial.md ...]

Runs every bash block of each tutorial, in order, in one shell, and fails on
the first that exits non-zero. With no arguments, runs every tutorial under
docs/ whose first line is <!-- tutorial: test sandbox=<path> -->.`;

/** The opt-in marker's attributes ({sandbox, checkout}), or null when the tutorial hasn't opted in. */
export function marker(markdown) {
  const m = markdown.split("\n", 1)[0].match(OPT_IN);
  if (!m) return null;
  return Object.fromEntries([...m[1].matchAll(/([a-z]+)=(\S+)/g)].map((a) => [a[1], a[2]]));
}

/** The opt-in marker's sandbox path, or null when the tutorial hasn't opted in. */
export function optIn(markdown) {
  const m = marker(markdown);
  return m === null ? null : (m.sandbox ?? "");
}

/** The tutorial's bash blocks in order, each with its heading and skip condition. */
export function steps(markdown) {
  const lines = markdown.split("\n");
  const out = [];
  let heading = "";
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^#{1,6}\s/.test(line)) heading = line.replace(/^#+\s*/, "");
    if (!/^```/.test(line)) continue;
    const isBash = /^```bash\s*$/.test(line);
    const skip = isBash && i > 0 ? lines[i - 1].match(SKIP) : null;
    const body = [];
    for (i++; i < lines.length && !/^```\s*$/.test(lines[i]); i++) body.push(lines[i]);
    if (isBash)
      out.push({
        heading,
        skipUnless: skip?.[1] === "unless" ? skip[2] : null,
        skipIf: skip?.[1] === "if" ? skip[2] : null,
        script: body.join("\n"),
      });
  }
  return out;
}

/** Whether a step is skipped: `skip unless VAR` without VAR set, or `skip if VAR` with it set. */
export function skipped(step, env) {
  return Boolean((step.skipUnless && !env[step.skipUnless]) || (step.skipIf && env[step.skipIf]));
}

/** One shell script for the steps to run, each announcing itself on stderr. Each [from, to] in rewrites is applied in order. */
export function script(stepList, rewrites, env = process.env) {
  const parts = ["set -e"];
  stepList.forEach((s, n) => {
    if (skipped(s, env)) return;
    let body = s.script;
    for (const [from, to] of rewrites) if (from) body = body.split(from).join(to);
    parts.push(`echo "::step ${n + 1}" >&2`, body);
  });
  return `${parts.join("\n")}\n`;
}

function findTutorials(dir) {
  const found = [];
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) found.push(...findTutorials(path));
    else if (name.endsWith(".md") && optIn(readFileSync(path, "utf8")) !== null) found.push(path);
  }
  return found.sort();
}

function runOne(path) {
  const markdown = readFileSync(path, "utf8");
  const { sandbox, checkout } = marker(markdown);
  const list = steps(markdown);
  const into = mkdtempSync(join(tmpdir(), "tutorial-"));
  const env = { ...process.env };
  if (checkout) {
    if (process.env.TUTORIAL_PUBLISHED) delete env[checkout];
    else env[checkout] = ROOT;
  }
  const res = spawnSync("bash", ["-c", script(list, [[sandbox, into]], env)], {
    env,
    cwd: into,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  const announced = [...res.stderr.matchAll(/^::step (\d+)$/gm)].map((m) => Number(m[1]));
  const last = announced.at(-1) ?? 0;
  const skippedCount = list.filter((s) => skipped(s, env)).length;
  const ok = res.status === 0;
  if (ok) rmSync(into, { recursive: true, force: true });
  const output = `${res.stdout}\n${res.stderr}`.replace(/^::step \d+\n/gm, "").trim();
  return {
    tutorial: relative(ROOT, path),
    against: checkout && env[checkout] ? "checkout" : "published",
    ok,
    steps: list.length,
    ran: announced.length,
    skipped: skippedCount,
    failed: ok
      ? null
      : {
          step: last,
          heading: list[last - 1]?.heading ?? "",
          exit: res.status,
          output: output.split("\n").slice(-20).join("\n"),
          sandbox: into,
        },
  };
}

function main(argv) {
  if (argv.includes("--help") || argv.includes("-h")) {
    console.log(USAGE);
    return 0;
  }
  const unknown = argv.find((a) => a.startsWith("-"));
  if (unknown) {
    console.error(`unknown option: ${unknown}\n${USAGE}`);
    return 1;
  }
  const paths = argv.length ? argv.map((a) => resolve(a)) : findTutorials(join(ROOT, "docs"));
  for (const p of paths) {
    if (!existsSync(p)) {
      console.error(`tutorial not found: ${p}`);
      return 2;
    }
    if (optIn(readFileSync(p, "utf8")) === null) {
      console.error(
        `${relative(ROOT, p)} has not opted in: its first line is not <!-- tutorial: test ... -->`,
      );
      return 1;
    }
  }
  const results = [];
  for (const p of paths) {
    console.error(`tutorial-smoke: ${relative(ROOT, p)}`);
    const r = runOne(p);
    console.error(
      r.ok
        ? `  ok: ${r.ran} of ${r.steps} steps ran, ${r.skipped} skipped`
        : `  FAILED at step ${r.failed.step} (${r.failed.heading}), exit ${r.failed.exit}; sandbox kept at ${r.failed.sandbox}\n${r.failed.output.replace(/^/gm, "    ")}`,
    );
    results.push(r);
  }
  console.log(JSON.stringify(results, null, 2));
  return results.every((r) => r.ok) ? 0 : 3;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)));
}
