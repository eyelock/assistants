#!/usr/bin/env node
// Runs a skill's evals/evals.json the agentskills.io way
// (https://agentskills.io/skill-creation/evaluating-skills): every case runs
// twice in a clean headless Claude Code session, once with the skill's plugin
// loaded and once without it, then an LLM judge grades each output against the
// case's assertions.
//
// Results land in .evals/<skill>-workspace/iteration-<N>/ at the repo root
// (gitignored), in the layout the spec describes: one directory per case, with
// with_skill/ and without_skill/ each holding outputs/, timing.json and
// grading.json, plus benchmark.json for the iteration.
//
// Each run is isolated: a fresh temp directory holding only the case's files
// under data/, user and local settings skipped (no CLAUDE.md, no installed
// plugins), no MCP servers, and read-only tools. The with-skill run adds
// --plugin-dir for the package that holds the skill, so the skill must still
// trigger from its description, as it would for a real user.
//
// A case can open a shell sandbox, an extension to the spec's case format:
//   "setup":    a script (relative to the skill) run with bash in the temp
//               directory first, e.g. to build a git repo with a local bare
//               origin. It gets $EVAL_FIXTURES, the skill's evals/files/.
//   "baseline_setup": a script run in place of "setup" in the without_skill arm,
//               the case's own control. The baseline hides the plugin and this
//               checkout, which is a fair control when the behaviour is written
//               in the skill. A case that grades text its setup installs (a
//               seat's charter, say) needs one that installs the same fixtures
//               without that text, or both arms read it. The report names each
//               run's control: "plugin hidden" (the default) or "baseline_setup".
//   "tools":    extra tools for the agent, e.g. ["Bash", "Edit(./**)"]. Any
//               Bash entry means shell access, and both arms get the same
//               unrestricted shell: the OS sandbox below is the boundary,
//               not a command allow-list, which a model defeats by phrasing
//               a command differently (an env prefix, a pipe, a heredoc) and
//               which would hold the baseline arm back unfairly.
//   "stubs":    commands replaced by recorders on PATH (default ["gh"] once
//               any Bash is granted); each call is logged, nothing runs.
//               A setup script can install richer stubs of its own, ones that
//               print realistic output, into $EVAL_BIN (first on PATH), and
//               log their calls to $EVAL_STUB_LOG.
//   "evidence": a shell command run after the agent; its output, with the
//               stub log, is saved and shown to the judge.
//   "forbidden": call patterns that fail the case outright. Each is a regular
//               expression (JS syntax, no slashes) matched against every line
//               of the stub log, which reads "<command> <arguments>", e.g.
//               "^gh pr merge" or "^git stash". A match fails the case with
//               no judge call, and the result names the call.
//   "required": call patterns that must each match some line of the stub log.
//               One that matches nothing fails the case the same way. The
//               plain checks run first; the judge grades "assertions" only
//               once they all pass, so write the soft part there.
//   "tool_calls": tools whose calls the judge should see, with their input,
//               with their input: the calls go to the judge with the
//               evidence. Grant the tool in "tools" too. Not every tool
//               loads in an eval session: AskUserQuestion does not
//               (assistants #133), so check the plain-text fallback.
//   "max_turns": this case's turn cap, for a long workflow (default: the
//               --max-turns option).
//   "seat":     a seat harness to wake instead of a bare Claude session: its path,
//               relative to the run's directory (a setup script lays the harness
//               out there) or absolute. The run is `ynh run <seat> -v <vendor> --
//               ...` with a scratch YNH_HOME inside the run's directory and
//               YNH_WORKSPACE_ROOTS set to that directory, so the harness's
//               workspace folders are granted with no `ynh trust accept` and
//               nothing touches the real ~/.ynh. The seat is what is under test,
//               not a skill, so a seat case has one arm (no without_skill).
//               --vendor (or VENDOR=) picks the vendor, default claude. Only
//               Claude's stream-json output is parsed today: on another vendor
//               the judge sees the reply as plain text and no tool-call view,
//               so a pass there rests on the plain checks and the reply alone.
// The sandbox also points git at an empty global config and gh at a host that
// does not resolve, so nothing reaches a real remote or credential. Any case
// that grants shell access runs under Claude Code's OS sandbox, which confines
// writes to the run's directory and blocks network access, whatever the
// command. Commands can still read files outside the run's directory; they
// cannot send them anywhere.
//
// Output: a JSON summary on stdout; progress on stderr.
// Exit codes: 0 success, 1 bad args, 2 file not found, 3 tool error.

import { spawn } from "node:child_process";
import {
  accessSync,
  chmodSync,
  constants,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const USAGE = `usage: node scripts/skill-evals.mjs <skill-dir> [options]

  <skill-dir>            directory holding SKILL.md and evals/evals.json

options:
  --case <name|id>       run only this case (repeatable)
  --iteration <n>        iteration number (default: next unused)
  --model <model>        model for the runs (default: sonnet; a cheap, steady
                         default so scores stay comparable between runs)
  --judge-model <model>  model for grading (default: sonnet)
  --max-turns <n>        turn cap per run (default: 15)
  -j, --concurrency <n>  runs at once, 1-8 (default: 4)
  --runs <n>             run each case n times per arm (default: 1); with
                         more than one, each arm holds run-1/, run-2/...
  --vendor <vendor>      vendor a seat case runs on, passed to ynh run -v (default:
                         $VENDOR, else claude); plain cases always run on claude
  --no-baseline          skip the without_skill runs
  --triggers             run evals/eval_queries.json instead: does the skill
                         fire for should_trigger queries, and only those?
  --help                 show this help`;

function fail(message, code = 1) {
  process.stderr.write(`skill-evals: ${message}\n`);
  process.exit(code);
}

function log(message) {
  process.stderr.write(`skill-evals: ${message}\n`);
}

function parseArgs(argv) {
  const opts = {
    cases: [],
    model: "sonnet",
    judgeModel: "sonnet",
    maxTurns: 15,
    concurrency: 4,
    runs: 1,
    baseline: true,
    vendor: process.env.VENDOR || "claude",
  };
  const rest = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const value = () => {
      if (i + 1 >= argv.length) fail(`${arg} needs a value`);
      return argv[++i];
    };
    switch (arg) {
      case "--help":
      case "-h":
        process.stdout.write(`${USAGE}\n`);
        process.exit(0);
        break;
      case "--case":
        opts.cases.push(value());
        break;
      case "--iteration":
        opts.iteration = Number.parseInt(value(), 10);
        break;
      case "--model":
        opts.model = value();
        break;
      case "--judge-model":
        opts.judgeModel = value();
        break;
      case "--max-turns":
        opts.maxTurns = Number.parseInt(value(), 10);
        break;
      case "-j":
      case "--concurrency":
        opts.concurrency = Number.parseInt(value(), 10);
        break;
      case "--runs":
        opts.runs = Number.parseInt(value(), 10);
        break;
      case "--vendor":
        opts.vendor = value();
        break;
      case "--no-baseline":
        opts.baseline = false;
        break;
      case "--triggers":
        opts.triggers = true;
        break;
      default:
        if (arg.startsWith("-")) fail(`unknown option ${arg}\n${USAGE}`);
        rest.push(arg);
    }
  }
  if (rest.length !== 1) fail(USAGE);
  if (!(opts.concurrency >= 1 && opts.concurrency <= 8)) fail("--concurrency must be 1-8");
  if (!(opts.maxTurns >= 1)) fail("--max-turns must be a positive integer");
  if (!(opts.runs >= 1)) fail("--runs must be a positive integer");
  opts.skillDir = resolve(rest[0]);
  return opts;
}

// The package is the nearest ancestor carrying a Claude plugin manifest: it is
// what --plugin-dir loads, so the skill runs beside its sibling skills, as
// installed.
function findPackage(skillDir) {
  let dir = dirname(skillDir);
  while (dir.startsWith(ROOT) && dir !== ROOT) {
    if (existsSync(join(dir, ".claude-plugin", "plugin.json"))) return dir;
    dir = dirname(dir);
  }
  fail(`no .claude-plugin/plugin.json above ${relative(ROOT, skillDir)}`, 2);
}

function readJson(path, what) {
  if (!existsSync(path)) fail(`${what} not found: ${relative(ROOT, path)}`, 2);
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (err) {
    fail(`${what} is not valid JSON: ${err.message}`);
  }
}

function writeJson(path, data) {
  writeFileSync(path, `${JSON.stringify(data, null, 2)}\n`);
}

function caseSlug(c) {
  return `eval-${c.name ?? c.id}`;
}

// Where one run's results go: the spec's <case>/<arm>/ for a single run, and
// <case>/<arm>/run-<n>/ when each case runs several times.
function runDir(c, arm, runNo, ctx) {
  const dir = join(ctx.iterationDir, caseSlug(c), arm);
  return ctx.runs > 1 ? join(dir, `run-${runNo}`) : dir;
}

// The arms a case runs: a seat case tests the seat as ynh assembles it, so there
// is no skill to take away and no control arm.
export function armsFor(c, baseline) {
  return c.seat || !baseline ? ["with_skill"] : ["with_skill", "without_skill"];
}

// The first executable called name on the real PATH, so a case that stubs ynh for
// other reasons (a recorder in $EVAL_BIN) cannot shadow the ynh that wakes the seat.
export function findOnPath(name, path = process.env.PATH ?? "") {
  for (const dir of path.split(":").filter(Boolean)) {
    const file = join(dir, name);
    try {
      accessSync(file, constants.X_OK);
      if (statSync(file).isFile()) return file;
    } catch {
      // not here
    }
  }
  return null;
}

// The command that wakes a case's seat through ynh, and the environment it needs.
// A scratch YNH_HOME keeps the real ~/.ynh out of it. The run's directory is the
// only workspace root, so the seat's workspace folders are granted with no trust
// step (a harness run from a path has no trust record anyway). The directory is
// resolved with realpath because ynh compares resolved paths and a macOS temp
// directory sits behind a symlink. Claude gets the run's own flags after --; any
// other vendor gets only the prompt, as its flags are not mapped yet.
export function seatLaunch(c, vendor, work, env, claudeArgs) {
  const root = realpathSync(work);
  const seat = resolve(root, c.seat);
  const passed = vendor === "claude" ? claudeArgs : ["-p", c.prompt];
  return {
    cmd: findOnPath("ynh") ?? "ynh",
    args: ["run", seat, "-v", vendor, "--", ...passed],
    env: {
      ...env,
      YNH_HOME: join(root, ".eval", "ynh-home"),
      YNH_WORKSPACE_ROOTS: root,
    },
  };
}

function nextIteration(workspace) {
  if (!existsSync(workspace)) return 1;
  const used = readdirSync(workspace)
    .map((name) => /^iteration-(\d+)$/.exec(name))
    .filter(Boolean)
    .map((m) => Number(m[1]));
  return used.length ? Math.max(...used) + 1 : 1;
}

function run(cmd, args, cwd, env = process.env) {
  // Claude Code's own memory would answer "remember this" or "next time" before
  // any skill could; a run tests the skill, not the harness running it.
  const runEnv = cmd === "claude" ? { ...env, CLAUDE_CODE_DISABLE_AUTO_MEMORY: "1" } : env;
  return new Promise((resolvePromise) => {
    const child = spawn(cmd, args, { cwd, env: runEnv, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => {
      stdout += d;
    });
    child.stderr.on("data", (d) => {
      stderr += d;
    });
    child.on("error", (err) => resolvePromise({ code: 127, stdout, stderr: String(err) }));
    child.on("close", (code) => resolvePromise({ code, stdout, stderr }));
  });
}

function parseEvents(stdout) {
  return stdout
    .split("\n")
    .filter((line) => line.trim().startsWith("{"))
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

// Skills the agent invoked, as "plugin:skill" names.
function skillCalls(events) {
  return events
    .filter((e) => e.type === "assistant")
    .flatMap((e) => e.message?.content ?? [])
    .filter((b) => b.type === "tool_use" && b.name === "Skill")
    .map((b) => b.input?.skill ?? b.input?.command)
    .filter(Boolean);
}

// The calls to the tools a case names in "tool_calls", with their input, so
// the judge can see how the agent used them (say, the questions it asked
// through a question tool, which never reach the final answer).
function toolCallsShown(c, events) {
  if (!c.tool_calls?.length) return "";
  const calls = events
    .filter((e) => e.type === "assistant")
    .flatMap((e) => e.message?.content ?? [])
    .filter((b) => b.type === "tool_use" && c.tool_calls.includes(b.name))
    .map((b) => `${b.name} ${JSON.stringify(b.input)}`);
  return `Calls to ${c.tool_calls.join(", ")}:\n${calls.join("\n") || "(none)"}`;
}

// Every run: no Claude Code auto memory, and no reading the copies of skills
// installed on this machine (a ynh cache, Claude Code's plugins), so the
// baseline arm can't find the skill under test and follow it anyway. The
// baseline arm can't read this checkout either: the skill's source is here,
// and a search for its name finds it. The with_skill arm loads the skill from
// the checkout with --plugin-dir, and runs its scripts from there. Every run
// works in its own temporary directory, outside the checkout, and the runner
// gathers evidence itself, so no case needs to read the checkout.
const INSTALLED_SKILLS = ["~/.ynh", "~/.claude/plugins"];
const hidden = (arm) => (arm === "without_skill" ? [...INSTALLED_SKILLS, ROOT] : INSTALLED_SKILLS);
// Read rules take an absolute path as //path; ~/ paths as they are.
const readRule = (dir) => `Read(${dir.startsWith("/") ? `/${dir}` : dir}/**)`;
const isolation = (arm) => ({
  autoMemoryEnabled: false,
  permissions: { deny: hidden(arm).map(readRule) },
});
const RUN_SETTINGS = JSON.stringify(isolation("with_skill"));

// Claude Code's OS sandbox: shell commands may write only inside the run's
// directory, read nothing the arm hides, and reach no network (all checked
// by hand). Commands that run inside it are approved automatically, and none
// may escape it.
const osSandbox = (arm) =>
  JSON.stringify({
    ...isolation(arm),
    sandbox: {
      enabled: true,
      autoAllowBashIfSandboxed: true,
      allowUnsandboxedCommands: false,
      filesystem: { denyRead: hidden(arm) },
    },
  });

const BASE_ARGS = [
  "--setting-sources",
  "project",
  "--strict-mcp-config",
  "--no-session-persistence",
];

// The setup script a run uses, and the control it stands for. The with_skill arm always runs
// the case's setup; the without_skill arm runs its baseline_setup when it names one.
export function setupFor(c, arm) {
  if (arm === "without_skill" && c.baseline_setup) {
    return { script: c.baseline_setup, control: "baseline_setup" };
  }
  return { script: c.setup, control: arm === "without_skill" ? "plugin hidden" : null };
}

// Sets up a case's shell sandbox, if it asks for one: stub commands on PATH
// that only record their calls, git and gh cut off from real config and
// hosts, then the case's setup script. Returns the environment for the run.
async function prepareSandbox(c, work, ctx, arm) {
  const { script: setupScript } = setupFor(c, arm);
  const wantsShell = (c.tools ?? []).some((tool) => tool.startsWith("Bash"));
  const stubs = c.stubs ?? (wantsShell ? ["gh"] : []);
  const binDir = join(work, ".eval", "bin");
  const stubLog = join(work, ".eval", "stub-calls.log");
  mkdirSync(binDir, { recursive: true });
  writeFileSync(stubLog, "");
  for (const name of stubs) {
    const stub = join(binDir, name);
    writeFileSync(
      stub,
      `#!/bin/sh\nprintf '%s\\n' "${name} $*" >> "${stubLog}"\necho "(${name} is stubbed in this eval; the call was recorded)"\n`,
    );
    chmodSync(stub, 0o755);
  }
  const gitConfig = join(work, ".eval", "gitconfig");
  writeFileSync(gitConfig, "[user]\n\tname = Eval User\n\temail = eval@example.invalid\n");
  const env = {
    ...process.env,
    PATH: `${binDir}:${process.env.PATH}`,
    EVAL_BIN: binDir,
    EVAL_STUB_LOG: stubLog,
    // Build caches live in the run's directory, the only place the OS sandbox
    // lets a command write. There is no network, so fixtures use only what the
    // toolchain ships with (no module or package downloads).
    XDG_CACHE_HOME: join(work, ".eval", "cache"),
    GOCACHE: join(work, ".eval", "cache", "go-build"),
    GOMODCACHE: join(work, ".eval", "cache", "go-mod"),
    GOPATH: join(work, ".eval", "go"),
    GOFLAGS: "-mod=mod",
    GOTOOLCHAIN: "local",
    EVAL_FIXTURES: join(ctx.skillDir, "..", "..", "evals", "files"),
    GIT_CONFIG_GLOBAL: gitConfig,
    GIT_CONFIG_NOSYSTEM: "1",
    GIT_TERMINAL_PROMPT: "0",
    GH_TOKEN: "eval-stub",
    GH_HOST: "stub.invalid",
  };
  if (setupScript) {
    const script = resolve(ctx.skillDir, setupScript);
    if (!existsSync(script)) fail(`case ${c.id}: setup not found: ${setupScript}`, 2);
    const res = await run("bash", [script], work, env);
    if (res.code !== 0) {
      fail(`case ${c.id}: setup failed (exit ${res.code}): ${res.stderr.trim().slice(0, 300)}`, 3);
    }
  }
  return { env, stubLog, wantsShell, used: wantsShell || stubs.length > 0 || Boolean(setupScript) };
}

// What a sandboxed run did, for the judge: the case's evidence command and
// every stubbed call.
async function collectEvidence(c, work, sandbox) {
  if (!sandbox.used) return "";
  const parts = [];
  if (c.evidence) {
    const res = await run("bash", ["-c", c.evidence], work, sandbox.env);
    parts.push(`$ ${c.evidence}\n${res.stdout}${res.stderr}`);
  }
  const calls = readFileSync(sandbox.stubLog, "utf8").trim();
  parts.push(`Stubbed command calls:\n${calls || "(none)"}`);
  return parts.join("\n\n");
}

// The plain checks on a run's stub log: no model involved. Returns one
// result per forbidden pattern (passed when no logged call matches it) and per
// required pattern (passed when some logged call does), each naming the call.
export function plainChecks(c, calls) {
  const lines = (calls ?? "")
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);
  const results = [];
  for (const pattern of c.forbidden ?? []) {
    const hit = lines.find((l) => new RegExp(pattern).test(l));
    results.push({
      text: `forbidden call /${pattern}/ was not made`,
      passed: hit === undefined,
      evidence: hit === undefined ? "no logged call matches" : `forbidden call made: ${hit}`,
    });
  }
  for (const pattern of c.required ?? []) {
    const hit = lines.find((l) => new RegExp(pattern).test(l));
    results.push({
      text: `required call /${pattern}/ was made`,
      passed: hit !== undefined,
      evidence: hit !== undefined ? `call made: ${hit}` : "no logged call matches",
    });
  }
  return results;
}

// One agent run: a clean temp directory with the case's files under data/.
async function runCase(c, arm, runNo, ctx) {
  const outDir = join(runDir(c, arm, runNo, ctx), "outputs");
  mkdirSync(outDir, { recursive: true });
  const work = mkdtempSync(join(tmpdir(), "skill-evals-"));
  try {
    if (c.files?.length) {
      mkdirSync(join(work, "data"), { recursive: true });
      for (const f of c.files) {
        const src = resolve(ctx.skillDir, f);
        if (!existsSync(src)) fail(`case ${c.id}: file not found: ${f}`, 2);
        cpSync(src, join(work, "data", basename(f)), { recursive: true });
      }
    }
    const sandbox = await prepareSandbox(c, work, ctx, arm);
    // Shell access is all-or-nothing: the OS sandbox confines it, so a case's
    // Bash patterns widen to plain Bash, for both arms alike.
    const extra = sandbox.wantsShell
      ? [...(c.tools ?? []).filter((tool) => !tool.startsWith("Bash")), "Bash"]
      : (c.tools ?? []);
    const granted = new Set(extra.map((tool) => tool.replace(/\(.*$/, "")));
    const args = [
      "-p",
      c.prompt,
      "--output-format",
      "stream-json",
      "--verbose",
      ...BASE_ARGS,
      "--max-turns",
      String(c.max_turns ?? ctx.maxTurns),
      "--allowedTools",
      ["Read", "Glob", "Grep", "Skill", ...extra].join(","),
      "--disallowedTools",
      ["Bash", "Write", "Edit", "NotebookEdit", "WebFetch", "WebSearch", "Agent"]
        .filter((tool) => !granted.has(tool))
        .join(","),
    ];
    // A seat's skills come from its own harness, through ynh, not from --plugin-dir.
    if (arm === "with_skill" && !c.seat) args.push("--plugin-dir", ctx.packageDir);
    args.push("--model", ctx.model);
    args.push("--settings", sandbox.wantsShell ? osSandbox(arm) : JSON.stringify(isolation(arm)));

    const started = Date.now();
    const launch = c.seat
      ? seatLaunch(c, ctx.vendor, work, sandbox.env, args)
      : { cmd: "claude", args, env: sandbox.env };
    const res = await run(launch.cmd, launch.args, work, launch.env);
    writeFileSync(join(outDir, "transcript.jsonl"), res.stdout);
    const events = parseEvents(res.stdout);
    const evidence = [await collectEvidence(c, work, sandbox), toolCallsShown(c, events)]
      .filter(Boolean)
      .join("\n\n");
    if (evidence) writeFileSync(join(outDir, "evidence.txt"), evidence);

    const result = events.findLast((e) => e.type === "result");
    const skillsUsed = skillCalls(events);

    // Without Claude's stream-json there is no result event: the reply is the output.
    const plain = c.seat && ctx.vendor !== "claude";
    const answer = plain ? res.stdout.trim() : (result?.result ?? "");
    writeFileSync(join(outDir, "answer.md"), `${answer}\n`);
    const u = result?.usage ?? {};
    const timing = {
      total_tokens:
        (u.input_tokens ?? 0) +
        (u.output_tokens ?? 0) +
        (u.cache_creation_input_tokens ?? 0) +
        (u.cache_read_input_tokens ?? 0),
      duration_ms: result?.duration_ms ?? Date.now() - started,
      cost_usd: result?.total_cost_usd ?? null,
      skills_used: skillsUsed,
      // Commands the permission rules refused. A refusal means the case's
      // "tools" grant did not match how the model phrased a command (an
      // env-var prefix, say), and the run stopped to ask: widen the grant.
      permission_denials: (result?.permission_denials ?? []).map(
        (d) => `${d.tool_name}: ${JSON.stringify(d.tool_input).slice(0, 160)}`,
      ),
    };
    writeJson(join(dirname(outDir), "timing.json"), timing);
    if ((!result && !plain) || res.code !== 0) {
      log(
        `${caseSlug(c)}/${arm}: ${launch.cmd} exited ${res.code}: ${res.stderr.trim().slice(0, 300)}`,
      );
    }
    const calls = existsSync(sandbox.stubLog) ? readFileSync(sandbox.stubLog, "utf8") : "";
    return {
      answer,
      evidence,
      calls,
      timing,
      ok: plain ? res.code === 0 : Boolean(result) && !result.is_error,
    };
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

// The case's input files, so the judge can check assertions about them (for
// example, that rows kept their original wording). Each is capped, so a large
// fixture cannot crowd out the output being graded.
const JUDGE_FILE_LIMIT = 20000;
function readTree(dir, prefix = "") {
  return readdirSync(dir)
    .sort()
    .map((name) => {
      const path = join(dir, name);
      const rel = `${prefix}${name}`;
      return statSync(path).isDirectory()
        ? readTree(path, `${rel}/`)
        : `--- ${rel}\n${readFileSync(path, "utf8")}`;
    })
    .join("\n");
}
function inputFiles(c, ctx) {
  if (!c.files?.length) return [];
  const blocks = c.files.map((f) => {
    const path = resolve(ctx.skillDir, f);
    let text;
    try {
      text = statSync(path).isDirectory() ? readTree(path) : readFileSync(path, "utf8");
    } catch {
      text = "(not readable as text)";
    }
    if (text.length > JUDGE_FILE_LIMIT) text = `${text.slice(0, JUDGE_FILE_LIMIT)}\n(truncated)`;
    return `<file name="data/${basename(f)}">\n${text}\n</file>`;
  });
  return ["The input files the assistant was given:", ...blocks, ""];
}

const GRADING_SCHEMA = {
  type: "object",
  properties: {
    assertion_results: {
      type: "array",
      items: {
        type: "object",
        properties: {
          text: { type: "string" },
          passed: { type: "boolean" },
          evidence: { type: "string" },
        },
        required: ["text", "passed", "evidence"],
      },
    },
  },
  required: ["assertion_results"],
};

export async function grade(c, arm, runNo, answer, evidence, ctx, calls = "") {
  const armDir = runDir(c, arm, runNo, ctx);
  const assertions = c.assertions ?? [];
  const plain = plainChecks(c, calls);
  const plainFailed = plain.some((r) => !r.passed);
  let results = [];
  if (assertions.length && !plainFailed) {
    const prompt = [
      "You are grading one output of an AI assistant against assertions.",
      "Grade each assertion PASS or FAIL. Require concrete evidence for a PASS: quote or point",
      "to the part of the output that satisfies it. Give no benefit of the doubt; a label",
      "without the substance is a FAIL. An empty output fails every assertion.",
      "",
      `The user asked:\n${c.prompt}`,
      "",
      `What success looks like:\n${c.expected_output ?? "(not given)"}`,
      "",
      ...inputFiles(c, ctx),
      ...(evidence
        ? [
            `What the assistant did in its sandbox, recorded after the run:\n<evidence>\n${evidence}\n</evidence>`,
            "",
          ]
        : []),
      `The output to grade:\n<output>\n${answer || "(empty)"}\n</output>`,
      "",
      "Assertions, to be returned in this order with their text unchanged:",
      ...assertions.map((a, i) => `${i + 1}. ${a}`),
    ].join("\n");
    const work = mkdtempSync(join(tmpdir(), "skill-evals-judge-"));
    try {
      const res = await run(
        "claude",
        [
          "-p",
          prompt,
          "--output-format",
          "json",
          ...BASE_ARGS,
          "--model",
          ctx.judgeModel,
          "--max-turns",
          "3",
          "--tools",
          "",
          "--json-schema",
          JSON.stringify(GRADING_SCHEMA),
        ],
        work,
      );
      let parsed = null;
      try {
        const out = JSON.parse(res.stdout);
        parsed = out.structured_output ?? JSON.parse(out.result);
      } catch {
        parsed = null;
      }
      results = parsed?.assertion_results ?? [];
      if (!parsed) log(`${caseSlug(c)}/${arm}: judge gave no grading (exit ${res.code})`);
    } finally {
      rmSync(work, { recursive: true, force: true });
    }
    // Keep the case's own assertion order and wording, whatever the judge returned.
    results = assertions.map((text, i) => {
      const r = results[i];
      return r
        ? { text, passed: Boolean(r.passed), evidence: r.evidence ?? "" }
        : { text, passed: false, evidence: "not graded" };
    });
  }
  // A failed plain check fails the case with no judge call: the soft
  // assertions are reported ungraded.
  if (plainFailed) {
    results = assertions.map((text) => ({
      text,
      passed: false,
      evidence: "not graded: a plain check failed",
    }));
  }
  results = [...plain, ...results];
  const passed = results.filter((r) => r.passed).length;
  const grading = {
    plain_check_failed: plainFailed,
    assertion_results: results,
    summary: {
      passed,
      failed: results.length - passed,
      total: results.length,
      pass_rate: results.length ? passed / results.length : null,
    },
  };
  writeJson(join(armDir, "grading.json"), grading);
  return grading;
}

function stats(values) {
  const xs = values.filter((v) => typeof v === "number");
  if (!xs.length) return { mean: null, stddev: null };
  const mean = xs.reduce((a, b) => a + b, 0) / xs.length;
  const variance = xs.reduce((a, b) => a + (b - mean) ** 2, 0) / xs.length;
  const round = (v) => Math.round(v * 1000) / 1000;
  return { mean: round(mean), stddev: round(Math.sqrt(variance)) };
}

async function pool(tasks, size) {
  const results = new Array(tasks.length);
  let next = 0;
  const worker = async () => {
    while (next < tasks.length) {
      const i = next++;
      results[i] = await tasks[i]();
    }
  };
  await Promise.all(Array.from({ length: Math.min(size, tasks.length) }, worker));
  return results;
}

// Trigger evals: each query runs once with the package loaded, in an empty
// directory, and passes when the skill fired exactly when should_trigger says.
// The run stops after a few turns; only whether the skill was invoked counts.
async function runTriggers(opts) {
  const queries = readJson(
    join(opts.skillDir, "evals", "eval_queries.json"),
    "evals/eval_queries.json",
  );
  const skillName = basename(opts.skillDir);
  const packageDir = findPackage(opts.skillDir);
  const workspace = join(ROOT, ".evals", `${skillName}-workspace`);
  const iteration = opts.iteration ?? nextIteration(workspace);
  const iterationDir = join(workspace, `iteration-${iteration}`);
  mkdirSync(iterationDir, { recursive: true });
  log(`${skillName}: ${queries.length} trigger quer(ies) -> ${relative(ROOT, iterationDir)}`);

  const tasks = queries.map((q) => async () => {
    const work = mkdtempSync(join(tmpdir(), "skill-evals-trigger-"));
    try {
      const args = [
        "-p",
        q.query,
        "--output-format",
        "stream-json",
        "--verbose",
        ...BASE_ARGS,
        "--max-turns",
        "3",
        "--allowedTools",
        "Read,Glob,Grep,Skill",
        "--disallowedTools",
        "Bash,Write,Edit,NotebookEdit,WebFetch,WebSearch,Agent",
        "--plugin-dir",
        packageDir,
        "--settings",
        RUN_SETTINGS,
      ];
      args.push("--model", opts.model);
      const res = await run("claude", args, work);
      const events = parseEvents(res.stdout);
      const used = skillCalls(events);
      // A run that never reached a result (rate limit, auth, crash) says
      // nothing about triggering: report it as an error, not as a miss.
      const result = events.findLast((e) => e.type === "result");
      if (!result || (result.is_error && !used.length)) {
        const reason =
          (result?.result ?? res.stderr ?? "").trim().slice(0, 200) || `exit ${res.code}`;
        log(`ERROR ${q.query}: ${reason}`);
        return {
          query: q.query,
          should_trigger: Boolean(q.should_trigger),
          error: reason,
          passed: false,
        };
      }
      const triggered = used.some((s) => s === skillName || s.endsWith(`:${skillName}`));
      const passed = triggered === Boolean(q.should_trigger);
      log(`${passed ? "PASS" : "FAIL"} ${q.should_trigger ? "+" : "-"} ${q.query}`);
      return {
        query: q.query,
        should_trigger: Boolean(q.should_trigger),
        triggered,
        skills_used: used,
        passed,
      };
    } finally {
      rmSync(work, { recursive: true, force: true });
    }
  });
  const results = await pool(tasks, opts.concurrency);
  const errors = results.filter((r) => r.error).length;
  if (errors) log(`${errors} quer(ies) errored; rerun before trusting this result`);
  const pos = results.filter((r) => r.should_trigger && !r.error);
  const neg = results.filter((r) => !r.should_trigger && !r.error);
  const rate = (xs) =>
    xs.length ? Math.round((xs.filter((r) => r.passed).length / xs.length) * 1000) / 1000 : null;
  const triggers = {
    skill_name: skillName,
    iteration,
    summary: {
      passed: results.filter((r) => r.passed).length,
      total: results.length,
      recall: rate(pos),
      specificity: rate(neg),
      errors,
    },
    results,
  };
  writeJson(join(iterationDir, "triggers.json"), triggers);
  process.stdout.write(`${JSON.stringify(triggers, null, 2)}\n`);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!existsSync(join(opts.skillDir, "SKILL.md"))) {
    fail(`no SKILL.md in ${relative(ROOT, opts.skillDir)}`, 2);
  }
  if (opts.triggers) return runTriggers(opts);
  const suite = readJson(join(opts.skillDir, "evals", "evals.json"), "evals/evals.json");
  const skillName = suite.skill_name ?? basename(opts.skillDir);
  let cases = suite.evals ?? [];
  if (opts.cases.length) {
    cases = cases.filter((c) => opts.cases.includes(String(c.id)) || opts.cases.includes(c.name));
    if (!cases.length) fail(`no case matches ${opts.cases.join(", ")}`);
  }

  const workspace = join(ROOT, ".evals", `${skillName}-workspace`);
  const iteration = opts.iteration ?? nextIteration(workspace);
  const ctx = {
    ...opts,
    packageDir: findPackage(opts.skillDir),
    iterationDir: join(workspace, `iteration-${iteration}`),
  };
  mkdirSync(ctx.iterationDir, { recursive: true });

  const arms = ["with_skill", "without_skill"].filter((a) =>
    cases.some((c) => armsFor(c, opts.baseline).includes(a)),
  );
  log(
    `${skillName}: ${cases.length} case(s) x ${arms.length} arm(s) x ${opts.runs} run(s) -> ${relative(ROOT, ctx.iterationDir)}`,
  );

  const runNumbers = Array.from({ length: opts.runs }, (_, i) => i + 1);
  const tasks = cases.flatMap((c) =>
    armsFor(c, opts.baseline).flatMap((arm) =>
      runNumbers.map((runNo) => async () => {
        const r = await runCase(c, arm, runNo, ctx);
        const g = await grade(c, arm, runNo, r.answer, r.evidence, ctx, r.calls);
        const label = `${caseSlug(c)}/${arm}${opts.runs > 1 ? `/run-${runNo}` : ""}`;
        log(
          `${label}: ${g.summary.passed}/${g.summary.total} passed` +
            (r.timing.skills_used.length ? `, skills: ${r.timing.skills_used.join(", ")}` : "") +
            (r.timing.permission_denials.length
              ? `, ${r.timing.permission_denials.length} command(s) refused: widen the case's tools`
              : ""),
        );
        return {
          case: caseSlug(c),
          arm,
          run: runNo,
          control: setupFor(c, arm).control,
          ...r.timing,
          ...g.summary,
        };
      }),
    ),
  );
  const runs = await pool(tasks, opts.concurrency);

  const summary = {};
  for (const arm of arms) {
    const mine = runs.filter((r) => r.arm === arm);
    summary[arm] = {
      pass_rate: stats(mine.map((r) => r.pass_rate)),
      time_seconds: stats(mine.map((r) => r.duration_ms / 1000)),
      tokens: stats(mine.map((r) => r.total_tokens)),
      skill_triggered: mine.filter((r) => r.skills_used?.length).length,
      runs: mine.length,
    };
  }
  if (summary.with_skill && summary.without_skill) {
    // A seat case runs only with the skill, so the delta compares the cases both arms ran.
    const both = new Set(runs.filter((r) => r.arm === "without_skill").map((r) => r.case));
    const paired = (arm) => {
      const mine = runs.filter((r) => r.arm === arm && both.has(r.case));
      return {
        pass_rate: stats(mine.map((r) => r.pass_rate)),
        time_seconds: stats(mine.map((r) => r.duration_ms / 1000)),
        tokens: stats(mine.map((r) => r.total_tokens)),
      };
    };
    const w = paired("with_skill");
    const wo = paired("without_skill");
    const d = (k) =>
      w[k].mean === null || wo[k].mean === null
        ? null
        : Math.round((w[k].mean - wo[k].mean) * 1000) / 1000;
    summary.delta = {
      pass_rate: d("pass_rate"),
      time_seconds: d("time_seconds"),
      tokens: d("tokens"),
    };
  }
  const benchmark = { skill_name: skillName, iteration, run_summary: summary, runs };
  writeJson(join(ctx.iterationDir, "benchmark.json"), benchmark);
  process.stdout.write(`${JSON.stringify(benchmark, null, 2)}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((err) => fail(err.stack ?? String(err), 3));
}
