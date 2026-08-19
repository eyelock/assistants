#!/usr/bin/env node
// JSON half of scripts/ynh-register.sh — see that script's header for the
// TermQ invocation contract. Invoked as:
//
//   node scripts/ynh-register.mjs <harness-dir>
//
// with the repo root as the working directory (the shell wrapper validates
// arguments and refreshes the lockfile afterwards). Responsibilities:
//
//   1. verify <harness-dir> is covered by a pnpm-workspace.yaml glob
//   2. map same-repo includes (manifest includes[] + profiles.*.includes[],
//      deduped) to @eyelock-assistants workspace:* dependencies
//   3. generate/refresh <harness-dir>/package.json, preserving hand-added keys
//
// Exit codes: 0 success, 1 validation error, 2 file not found / unreadable.

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const SCOPE = "@eyelock-assistants";
// Git URLs identifying this repository, compared on the normalized
// host/owner/repo tail (see normalizeGitUrl).
const SELF_REPO = "github.com/eyelock/assistants";
// Keys this script owns and regenerates on every run; anything else found in
// an existing package.json is preserved verbatim.
const GENERATED_KEYS = ["name", "version", "private", "description", "dependencies"];

function log(message) {
  process.stdout.write(`ynh-register: ${message}\n`);
}

function fail(message, code = 1) {
  process.stderr.write(`ynh-register: error: ${message}\n`);
  process.exit(code);
}

function readJson(path, what) {
  let raw;
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    fail(`${what} not found at ${path}`, 2);
  }
  try {
    return JSON.parse(raw);
  } catch (err) {
    fail(
      `${what} at ${path} is not valid JSON (${err.message}) — fix or delete it, then re-run`,
      2,
    );
  }
}

// Reduce a git URL to its host/owner/repo tail so that
// https://github.com/eyelock/assistants, github.com/eyelock/assistants/,
// git@github.com:eyelock/assistants.git and ssh://git@github.com/eyelock/assistants
// all compare equal (case-insensitive).
function normalizeGitUrl(url) {
  return String(url)
    .trim()
    .toLowerCase()
    .replace(/^git\+/, "")
    .replace(/^[a-z][a-z0-9+.-]*:\/\//, "") // scheme: https://, ssh://, git://
    .replace(/^[^/@]+@/, "") // user prefix: git@github.com…
    .replace(/^([^/:]+):/, "$1/") // scp-style host:owner/repo
    .replace(/\/+$/, "")
    .replace(/\.git$/, "");
}

// All includes from the manifest: top-level includes[] plus every
// profiles.<name>.includes[], deduped by normalized (git, path).
function collectIncludes(manifest) {
  const lists = [manifest.includes];
  for (const profile of Object.values(manifest.profiles ?? {})) {
    lists.push(profile?.includes);
  }
  const seen = new Set();
  const includes = [];
  for (const list of lists) {
    if (!Array.isArray(list)) continue;
    for (const include of list) {
      if (!include || typeof include !== "object") continue;
      const key = JSON.stringify([normalizeGitUrl(include.git ?? ""), include.path ?? ""]);
      if (seen.has(key)) continue;
      seen.add(key);
      includes.push(include);
    }
  }
  return includes;
}

// Same-repo includes become workspace:* dependencies. The package name comes
// from the include path's own package.json — names are not derivable from
// paths (skills/dev → @eyelock-assistants/dev-skills). `pick` filters do not
// narrow the dependency; we depend on the whole package. Includes pointing at
// other repos are not workspace packages and are skipped.
function mapWorkspaceDependencies(root, manifestRel, manifest) {
  const dependencies = {};
  for (const include of collectIncludes(manifest)) {
    if (normalizeGitUrl(include.git ?? "") !== SELF_REPO) continue;
    if (!include.path) {
      fail(
        `a same-repo include in ${manifestRel} has no "path" — point it at a workspace package (e.g. "skills/dev")`,
      );
    }
    const packageJsonPath = join(root, include.path, "package.json");
    if (!existsSync(packageJsonPath)) {
      fail(
        `include path "${include.path}" has no package.json in this repo — check the include's "path" against the workspace packages under plugins/, skills/ and ynh/`,
        2,
      );
    }
    const name = readJson(packageJsonPath, `package.json for include "${include.path}"`).name;
    if (!name) {
      fail(
        `${include.path}/package.json has no "name" — add one so the include can map to a workspace dependency`,
      );
    }
    dependencies[name] = "workspace:*";
  }
  return dependencies;
}

// Minimal parser for this repo's pnpm-workspace.yaml: a block-style
// `packages:` list of glob strings.
function workspaceGlobs(root) {
  const yamlPath = join(root, "pnpm-workspace.yaml");
  if (!existsSync(yamlPath)) {
    fail(`pnpm-workspace.yaml not found in ${root} — run from the repo root`, 2);
  }
  const globs = [];
  let inPackages = false;
  for (const line of readFileSync(yamlPath, "utf8").split("\n")) {
    if (/^packages\s*:/.test(line)) {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    const item = line.match(/^\s+-\s*["']?([^"'#]+?)["']?\s*$/);
    if (item) globs.push(item[1]);
    else if (/^\S/.test(line)) inPackages = false; // next top-level key
  }
  if (!globs.length) {
    fail(
      'could not read a packages list from pnpm-workspace.yaml — expected a block list like `packages:` / `- "ynh/*"`',
    );
  }
  return globs;
}

// Just enough glob support for pnpm workspace package patterns:
// `*` (no slash), `**` (any depth), `?` (single char).
function globToRegExp(glob) {
  const pattern = glob
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .split("**")
    .map((part) => part.replace(/\*/g, "[^/]*").replace(/\?/g, "[^/]"))
    .join(".*");
  return new RegExp(`^${pattern}$`);
}

function checkWorkspaceCoverage(root, harnessDir) {
  const globs = workspaceGlobs(root);
  const covered =
    globs.some((g) => !g.startsWith("!") && globToRegExp(g).test(harnessDir)) &&
    !globs.some((g) => g.startsWith("!") && globToRegExp(g.slice(1)).test(harnessDir));
  if (!covered) {
    const suggestion = harnessDir.includes("/") ? `${harnessDir.split("/")[0]}/*` : harnessDir;
    fail(
      `${harnessDir} is not covered by pnpm-workspace.yaml (packages: ${globs.join(", ")}) — ` +
        `add a glob matching it (e.g. "${suggestion}") to pnpm-workspace.yaml and re-run; ` +
        "changing workspace topology is a reviewed decision, so this script will not edit it",
    );
  }
}

// The generated keys in canonical order, then any hand-added keys from an
// existing wrapper in their original order (mirrors sync-manifests.mjs).
function buildWrapper(manifest, dependencies, existing) {
  const pkg = {
    name: `${SCOPE}/${manifest.name}`,
    version: manifest.version,
    private: true,
    description: manifest.description ?? "",
  };
  if (Object.keys(dependencies).length) pkg.dependencies = dependencies;
  for (const [key, value] of Object.entries(existing)) {
    if (!GENERATED_KEYS.includes(key)) pkg[key] = value;
  }
  return pkg;
}

const harnessDir = process.argv[2];
if (!harnessDir) {
  fail("usage: node scripts/ynh-register.mjs <harness-dir>");
}

const root = process.cwd();
const manifestRel = join(harnessDir, ".ynh-plugin", "plugin.json");
const manifest = readJson(join(root, manifestRel), "harness manifest");
if (!manifest.name) {
  fail(`${manifestRel} has no "name" — add one (it becomes the ${SCOPE}/<name> package name)`);
}
if (!manifest.version) {
  fail(`${manifestRel} has no "version" — add one (e.g. "0.1.0")`);
}

checkWorkspaceCoverage(root, harnessDir);
const dependencies = mapWorkspaceDependencies(root, manifestRel, manifest);

const wrapperPath = join(root, harnessDir, "package.json");
const current = existsSync(wrapperPath) ? readFileSync(wrapperPath, "utf8") : null;
const existing = current === null ? {} : readJson(wrapperPath, "existing package.json wrapper");
const pkg = buildWrapper(manifest, dependencies, existing);
const next = `${JSON.stringify(pkg, null, 2)}\n`;

const depCount = Object.keys(dependencies).length;
const summary = `${pkg.name}@${pkg.version}, ${depCount} workspace dep${depCount === 1 ? "" : "s"}`;
const wrapperRel = join(harnessDir, "package.json");
if (current === next) {
  log(`${wrapperRel} already up to date (${summary})`);
} else {
  writeFileSync(wrapperPath, next);
  log(`${current === null ? "wrote" : "refreshed"} ${wrapperRel} (${summary})`);
}
