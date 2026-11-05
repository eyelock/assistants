#!/usr/bin/env node
// Single source of truth: .harness.json, .claude-plugin/plugin.json or, for a ynh
// harness that has neither, .agents/harness/plugin.json (in that order).
// This script projects those into minimal `package.json` mirrors so changesets
// (which only understands package.json) can operate on the workspace, and
// writes version bumps back to the source manifest after `changeset version`.
//
// Modes:
//   generate  — write package.json from source manifest (run pre-install, pre-changeset)
//   writeback — copy package.json version -> source manifest (run post `changeset version`)
//   check     — fail if any package.json is out of sync with its source (CI gate)

import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// SYNC_MANIFESTS_ROOT lets the tests run the script over a scratch tree.
const ROOT = process.env.SYNC_MANIFESTS_ROOT
  ? resolve(process.env.SYNC_MANIFESTS_ROOT)
  : resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SCOPE = "@eyelock-assistants";

// Workspace roots — every direct subdirectory is a candidate package.
const WORKSPACE_ROOTS = ["plugins", "skills", "ynh"];

// Marketplace indexes whose plugin `version` fields mirror the source manifests.
// `.github/plugin/marketplace.json` is the Copilot CLI-safe index: Copilot resolves it
// before falling back to `.claude-plugin/marketplace.json`, and it must avoid the
// `git-subdir` / `archive` / `command` source types Claude allows but Copilot rejects —
// one unsupported entry fails the whole index for Copilot. See
// plugins/vendor-harness/skills/vendor-adapters/references/copilot.md.
const MARKETPLACES = [
  ".claude-plugin/marketplace.json",
  ".cursor-plugin/marketplace.json",
  ".github/plugin/marketplace.json",
];

// The source manifest of a package directory, and what kind of package it is. A ynh
// harness keeps its manifest only in .agents/harness/ (assistants #44); a plugin that
// also has .claude-plugin/plugin.json keeps that as its source and .agents/harness/
// holds a vendor mirror of it.
function findSource(dir) {
  const harnessManifest = join(dir, ".harness.json");
  if (existsSync(harnessManifest)) return { source: harnessManifest, kind: "harness" };
  const pluginManifest = join(dir, ".claude-plugin", "plugin.json");
  if (existsSync(pluginManifest)) return { source: pluginManifest, kind: "plugin" };
  const agentsManifest = join(dir, ".agents", "harness", "plugin.json");
  if (existsSync(agentsManifest)) return { source: agentsManifest, kind: "harness" };
  return null;
}

function discoverPackages() {
  const dirs = WORKSPACE_ROOTS.flatMap((root) => {
    const rootDir = join(ROOT, root);
    if (!existsSync(rootDir)) return [];
    return readdirSync(rootDir)
      .map((name) => join(rootDir, name))
      .filter((p) => statSync(p).isDirectory());
  });
  return dirs
    .map((dir) => {
      const found = findSource(dir);
      return found ? { dir, ...found } : null;
    })
    .filter(Boolean);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

// JSON with object keys sorted, so two dependency maps compare equal whatever their order.
function canonical(value) {
  return JSON.stringify(value, (_, v) =>
    v && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b)))
      : v,
  );
}

function writeJson(path, data) {
  writeFileSync(path, `${JSON.stringify(data, null, 2)}\n`);
}

// Replace just the top-level `"version": "..."` field, preserving all other
// formatting. Used for writes to user-owned manifests (.harness.json, vendor
// plugin.json, registry.json, marketplace.json) so biome's array formatting
// isn't disturbed by a JSON round-trip. Returns true if the file changed.
function updateVersionInPlace(path, newVersion) {
  const src = readFileSync(path, "utf8");
  const re = /("version"\s*:\s*")([^"]+)(")/;
  const m = src.match(re);
  if (!m) return false;
  if (m[2] === newVersion) return false;
  writeFileSync(path, src.replace(re, `$1${newVersion}$3`));
  return true;
}

// Build the package.json that mirrors the source manifest.
// - name is scoped to avoid collision with marketplace names
// - dependencies are derived from harness `includes[*].path` -> workspace:*
function projectPackageJson({ source, kind }) {
  const manifest = readJson(source);
  if (!manifest.name) throw new Error(`${source}: missing "name"`);
  if (!manifest.version) throw new Error(`${source}: missing "version"`);

  const pkg = {
    name: `${SCOPE}/${manifest.name}`,
    version: manifest.version,
    private: true,
    description: manifest.description ?? "",
  };

  if (kind === "harness") {
    const deps = {};
    for (const inc of sameRepoIncludes(manifest)) {
      const depDir = join(ROOT, inc.path);
      const depPkg = findPackageAt(depDir);
      if (depPkg) deps[depPkg] = "workspace:*";
    }
    if (Object.keys(deps).length) pkg.dependencies = deps;
  }

  return pkg;
}

// A harness's includes: the top-level list plus every profiles.<name>.includes list, as
// scripts/ynh-register.mjs reads them, so both scripts write the same dependencies. Only
// includes that name a path in this repository are workspace packages: one with a `git`
// URL for another repository is not (a path-only include is local).
const SELF_REPO = "github.com/eyelock/assistants";
function normalizeGitUrl(url) {
  return String(url)
    .trim()
    .toLowerCase()
    .replace(/^git\+/, "")
    .replace(/^[a-z][a-z0-9+.-]*:\/\//, "")
    .replace(/^[^/@]+@/, "")
    .replace(/^([^/:]+):/, "$1/")
    .replace(/\/+$/, "")
    .replace(/\.git$/, "");
}

function sameRepoIncludes(manifest) {
  const lists = [manifest.includes];
  for (const profile of Object.values(manifest.profiles ?? {})) lists.push(profile?.includes);
  return lists
    .filter(Array.isArray)
    .flat()
    .filter(
      (inc) =>
        inc &&
        typeof inc === "object" &&
        inc.path &&
        (!inc.git || normalizeGitUrl(inc.git) === SELF_REPO),
    );
}

function findPackageAt(dir) {
  try {
    const found = findSource(dir);
    if (found) return `${SCOPE}/${readJson(found.source).name}`;
  } catch {
    /* ignore malformed */
  }
  return null;
}

function cmdGenerate(pkgs) {
  for (const p of pkgs) {
    const target = join(p.dir, "package.json");
    const projected = projectPackageJson(p);
    // Preserve any hand-edited fields (devDependencies, scripts) if they exist.
    if (existsSync(target)) {
      const existing = readJson(target);
      for (const k of ["scripts", "devDependencies"]) {
        if (existing[k]) projected[k] = existing[k];
      }
      // Keep the existing order of dependencies that are the same set.
      if (canonical(existing.dependencies) === canonical(projected.dependencies)) {
        if (existing.dependencies) projected.dependencies = existing.dependencies;
      }
    }
    writeJson(target, projected);
    process.stdout.write(`  generate ${relative(ROOT, target)}\n`);
    syncVendorPluginManifests(p);
  }
  syncRegistry(pkgs);
  syncMarketplaces(pkgs);
}

// Each package also carries vendor plugin manifests consumed by each marketplace.
// They are downstream of the source manifest: we sync the `version` field into
// them, leaving any vendor-specific keys untouched.
function syncVendorPluginManifests(p) {
  const manifest = readJson(p.source);
  for (const rel of [
    ".claude-plugin/plugin.json",
    ".cursor-plugin/plugin.json",
    ".agents/harness/plugin.json",
    ".codex-plugin/plugin.json",
  ]) {
    const target = join(p.dir, rel);
    if (target === p.source || !existsSync(target)) continue;
    if (updateVersionInPlace(target, manifest.version)) {
      process.stdout.write(`  sync      ${relative(ROOT, target)}\n`);
    }
  }
}

// Map from workspace package → { version, name (from source manifest) }.
function versionMap(pkgs) {
  const map = new Map();
  for (const p of pkgs) {
    const m = readJson(p.source);
    map.set(relative(ROOT, p.dir), { name: m.name, version: m.version });
  }
  return map;
}

function syncRegistry(pkgs) {
  const path = join(ROOT, "registry.json");
  if (!existsSync(path)) return;
  const reg = readJson(path);
  const vmap = versionMap(pkgs);
  let changed = false;
  for (const entry of reg.entries ?? []) {
    const v = vmap.get(entry.path);
    if (v && entry.version !== v.version) {
      entry.version = v.version;
      changed = true;
    }
  }
  if (changed) {
    writeJson(path, reg);
    process.stdout.write(`  sync      ${relative(ROOT, path)}\n`);
  }
}

function syncMarketplaces(pkgs) {
  const vmap = versionMap(pkgs);
  for (const rel of MARKETPLACES) {
    const path = join(ROOT, rel);
    if (!existsSync(path)) continue;
    const mp = readJson(path);
    let changed = false;
    for (const entry of mp.plugins ?? []) {
      // source can be "./plugins/foo" (string) or { source: "github", ... } (external)
      if (typeof entry.source !== "string") continue;
      const entryPath = entry.source.replace(/^\.\//, "");
      const v = vmap.get(entryPath);
      if (v && entry.version !== v.version) {
        entry.version = v.version;
        changed = true;
      }
    }
    if (changed) {
      writeJson(path, mp);
      process.stdout.write(`  sync      ${rel}\n`);
    }
  }
}

function cmdWriteback(pkgs) {
  for (const p of pkgs) {
    const target = join(p.dir, "package.json");
    if (!existsSync(target)) continue;
    const pkgJson = readJson(target);
    if (updateVersionInPlace(p.source, pkgJson.version)) {
      process.stdout.write(`  writeback ${relative(ROOT, p.source)} -> ${pkgJson.version}\n`);
    }
  }
}

function cmdCheck(pkgs) {
  const drift = [];
  for (const p of pkgs) {
    const target = join(p.dir, "package.json");
    const projected = projectPackageJson(p);
    if (!existsSync(target)) {
      drift.push(`missing: ${relative(ROOT, target)}`);
      continue;
    }
    const existing = readJson(target);
    // Ignore scripts/devDependencies; compare the projected keys only.
    for (const k of Object.keys(projected)) {
      if (canonical(existing[k]) !== canonical(projected[k])) {
        drift.push(`${relative(ROOT, target)}: ${k} out of sync`);
      }
    }
  }
  for (const p of pkgs) {
    const manifest = readJson(p.source);
    for (const rel of [
      ".claude-plugin/plugin.json",
      ".cursor-plugin/plugin.json",
      ".agents/harness/plugin.json",
      ".codex-plugin/plugin.json",
    ]) {
      const target = join(p.dir, rel);
      if (target === p.source || !existsSync(target)) continue;
      const vendor = readJson(target);
      if (vendor.version && vendor.version !== manifest.version) {
        drift.push(`${relative(ROOT, target)} version ${vendor.version} != ${manifest.version}`);
      }
    }
  }
  const vmap = versionMap(pkgs);
  const regPath = join(ROOT, "registry.json");
  if (existsSync(regPath)) {
    const reg = readJson(regPath);
    for (const entry of reg.entries ?? []) {
      const v = vmap.get(entry.path);
      if (v && entry.version !== v.version) {
        drift.push(`registry.json:${entry.name} version ${entry.version} != ${v.version}`);
      }
    }
  }
  for (const rel of MARKETPLACES) {
    const path = join(ROOT, rel);
    if (!existsSync(path)) continue;
    const mp = readJson(path);
    for (const entry of mp.plugins ?? []) {
      if (typeof entry.source !== "string") continue;
      const entryPath = entry.source.replace(/^\.\//, "");
      const v = vmap.get(entryPath);
      if (v && entry.version !== v.version) {
        drift.push(`${rel}:${entry.name} version ${entry.version} != ${v.version}`);
      }
    }
  }
  if (drift.length) {
    process.stderr.write("manifest drift detected:\n");
    for (const d of drift) process.stderr.write(`  ${d}\n`);
    process.stderr.write("run: pnpm sync-manifests generate\n");
    process.exit(1);
  }
  process.stdout.write("manifests in sync\n");
}

function cmdLocate(pkgs, name) {
  if (!name) {
    process.stderr.write("usage: sync-manifests.mjs locate <package-name>\n");
    process.exit(2);
  }
  for (const p of pkgs) {
    const m = readJson(p.source);
    if (m.name === name || `${SCOPE}/${m.name}` === name) {
      process.stdout.write(`${relative(ROOT, p.dir)}\n`);
      return;
    }
  }
  process.exit(1);
}

const [, , mode = "generate", arg] = process.argv;
const pkgs = discoverPackages();
if (mode === "generate") cmdGenerate(pkgs);
else if (mode === "writeback") cmdWriteback(pkgs);
else if (mode === "check") cmdCheck(pkgs);
else if (mode === "locate") cmdLocate(pkgs, arg);
else {
  process.stderr.write(`unknown mode: ${mode}\n`);
  process.stderr.write("usage: sync-manifests.mjs [generate|writeback|check|locate]\n");
  process.exit(2);
}
