#!/usr/bin/env node
// Keeps the common triage questions (assets/questions.json) and the platform harnesses in step.
//
//   node triage-questions.mjs check [--root <repo>]   report every mismatch, exit 1 if any
//   node triage-questions.mjs sync  [--root <repo>]   write the generated focuses into each harness
//
// After `sync`, format the changed manifests (`pnpm exec biome format --write`).
//
// Exit codes: 0 success, 1 mismatches found by check, 2 bad arguments or unreadable files.

import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const LIST = join("skills", "triage", "skills", "add-triage-question", "assets", "questions.json");

export function findRoot(from) {
  let dir = resolve(from);
  while (!existsSync(join(dir, LIST))) {
    const up = dirname(dir);
    if (up === dir) throw new Error(`no ${LIST} above ${from}`);
    dir = up;
  }
  return dir;
}

const readJson = (path) => JSON.parse(readFileSync(path, "utf8"));
const manifestPath = (root, harness) =>
  join(root, "ynh", harness, ".agents", "harness", "plugin.json");

export function load(root) {
  return readJson(join(root, LIST));
}

/** The focus prompt a question generates for a platform. */
export function promptFor(question, platform) {
  const skills = question.skills.join(" and ");
  const noun = question.skills.length === 1 ? "skill" : "skills";
  return `Use the ${skills} ${noun} to ${question.ask.replaceAll("{at}", platform.at)}`;
}

const buckets = (question) => ({
  on: question.on ?? [],
  not_on: Object.keys(question.not_on ?? {}),
  todo: question.todo ?? [],
});

/** Every mismatch between the list and the repository, as plain sentences. */
export function check(root) {
  const problems = [];
  const list = load(root);
  const harnesses = Object.keys(list.platforms);

  for (const harness of harnesses) {
    if (!existsSync(manifestPath(root, harness)))
      problems.push(`platforms lists ${harness}, but ynh/${harness} has no harness manifest`);
  }

  // A harness that includes the triage package but is not in the list would be missed.
  const ynh = join(root, "ynh");
  for (const dir of existsSync(ynh) ? readdirSync(ynh) : []) {
    if (harnesses.includes(dir) || !existsSync(manifestPath(root, dir))) continue;
    const manifest = readJson(manifestPath(root, dir));
    const triages = (manifest.includes ?? []).some((i) => i.path === "skills/triage" && !i.pick);
    if (triages && manifest.focuses)
      problems.push(
        `ynh/${dir} includes skills/triage but is not in platforms: add it, or say why it is not a platform`,
      );
  }

  const seen = new Set();
  for (const q of list.questions) {
    if (seen.has(q.id)) problems.push(`question ${q.id} is listed twice`);
    seen.add(q.id);
    for (const skill of q.skills) {
      if (!existsSync(join(root, "skills", "triage", "skills", skill, "SKILL.md")))
        problems.push(`${q.id}: skill ${skill} does not exist in skills/triage`);
    }
    const b = buckets(q);
    for (const [name, reason] of Object.entries(q.not_on ?? {})) {
      if (typeof reason !== "string" || reason.trim().length < 10)
        problems.push(`${q.id}: not_on ${name} needs a reason of at least a sentence`);
    }
    for (const harness of harnesses) {
      const where = Object.entries(b)
        .filter(([, names]) => names.includes(harness))
        .map(([bucket]) => bucket);
      if (where.length !== 1)
        problems.push(
          `${q.id}: ${harness} must be in exactly one of on, not_on or todo (it is in ${where.length})`,
        );
    }
    for (const name of Object.values(b).flat()) {
      if (!harnesses.includes(name)) problems.push(`${q.id}: ${name} is not in platforms`);
    }

    for (const harness of harnesses) {
      if (!existsSync(manifestPath(root, harness))) continue;
      const focuses = readJson(manifestPath(root, harness)).focuses ?? {};
      const focus = focuses[q.id];
      if (b.on.includes(harness)) {
        const want = promptFor(q, list.platforms[harness]);
        if (!focus) problems.push(`${q.id}: ynh/${harness} has no ${q.id} focus (run sync)`);
        else if (focus.prompt !== want)
          problems.push(`${q.id}: ynh/${harness} focus prompt differs from the list (run sync)`);
        const ref = join(root, "skills", "platforms", "skills", harness, "references", "triage.md");
        if (!existsSync(ref)) problems.push(`${q.id}: skills/platforms/skills/${harness}/references/triage.md is missing`);
        else if (!readFileSync(ref, "utf8").includes(q.id))
          problems.push(
            `${q.id}: the ${harness} skill's references/triage.md never mentions ${q.id}: say where to look`,
          );
      } else if (focus) {
        problems.push(`${q.id}: ynh/${harness} has a ${q.id} focus but the list does not have it on`);
      }
    }
  }
  return problems;
}

/** Writes each `on` question's focus into its harness. Returns the harnesses it changed. */
export function sync(root) {
  const list = load(root);
  const changed = [];
  for (const [harness, platform] of Object.entries(list.platforms)) {
    const path = manifestPath(root, harness);
    if (!existsSync(path)) continue;
    const manifest = readJson(path);
    const before = JSON.stringify(manifest.focuses ?? {});
    const generated = {};
    for (const q of list.questions) {
      if (!(q.on ?? []).includes(harness)) continue;
      generated[q.id] = { ...manifest.focuses?.[q.id], prompt: promptFor(q, platform) };
    }
    const questionIds = new Set(list.questions.map((q) => q.id));
    const rest = Object.fromEntries(
      Object.entries(manifest.focuses ?? {}).filter(([id]) => !questionIds.has(id)),
    );
    manifest.focuses = { ...generated, ...rest };
    if (JSON.stringify(manifest.focuses) === before) continue;
    writeFileSync(path, `${JSON.stringify(manifest, null, 2)}\n`);
    changed.push(harness);
  }
  return changed;
}

function main(argv) {
  const [command, ...rest] = argv;
  const flag = rest.indexOf("--root");
  if (!["check", "sync"].includes(command) || (flag !== -1 && !rest[flag + 1])) {
    console.error("usage: triage-questions.mjs check|sync [--root <repo>]");
    return 2;
  }
  let root;
  try {
    root = flag === -1 ? findRoot(here) : resolve(rest[flag + 1]);
    if (command === "sync") {
      const changed = sync(root);
      console.log(changed.length ? `updated: ${changed.join(", ")}` : "already in step");
      return 0;
    }
    const problems = check(root);
    for (const p of problems) console.error(`- ${p}`);
    if (!problems.length) console.log("triage questions are in step");
    return problems.length ? 1 : 0;
  } catch (error) {
    console.error(`triage-questions: ${error.message}`);
    return 2;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  process.exitCode = main(process.argv.slice(2));
}
