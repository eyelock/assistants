#!/usr/bin/env node
// Single source of truth: plugin.json / .harness.json.
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

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SCOPE = "@eyelock-assistants";

// Workspace roots — every direct subdirectory is a candidate package.
const WORKSPACE_ROOTS = ["plugins", "skills", "ynh"];

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
      const pluginManifest = join(dir, ".claude-plugin", "plugin.json");
      const harnessManifest = join(dir, ".harness.json");
      let source, kind;
      if (existsSync(harnessManifest)) {
        source = harnessManifest;
        kind = "harness";
      } else if (existsSync(pluginManifest)) {
        source = pluginManifest;
        kind = "plugin";
      } else {
        return null;
      }
      return { dir, source, kind };
    })
    .filter(Boolean);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeJson(path, data) {
  writeFileSync(path, JSON.stringify(data, null, 2) + "\n");
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

  if (kind === "harness" && Array.isArray(manifest.includes)) {
    const deps = {};
    for (const inc of manifest.includes) {
      if (!inc.path) continue;
      const depDir = join(ROOT, inc.path);
      const depPkg = findPackageAt(depDir);
      if (depPkg) deps[depPkg] = "workspace:*";
    }
    if (Object.keys(deps).length) pkg.dependencies = deps;
  }

  return pkg;
}

function findPackageAt(dir) {
  const pluginManifest = join(dir, ".claude-plugin", "plugin.json");
  const harnessManifest = join(dir, ".harness.json");
  try {
    if (existsSync(harnessManifest)) {
      return `${SCOPE}/${readJson(harnessManifest).name}`;
    }
    if (existsSync(pluginManifest)) {
      return `${SCOPE}/${readJson(pluginManifest).name}`;
    }
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
    }
    writeJson(target, projected);
    process.stdout.write(`  generate ${relative(ROOT, target)}\n`);
    syncVendorPluginManifests(p);
  }
  syncRegistry(pkgs);
  syncMarketplaces(pkgs);
}

// Each package also carries `.claude-plugin/plugin.json` and optionally
// `.cursor-plugin/plugin.json` — vendor-specific manifests consumed by each
// marketplace. They are downstream of `.harness.json`: we sync the `version`
// field into them, leaving any vendor-specific keys untouched.
function syncVendorPluginManifests(p) {
  const manifest = readJson(p.source);
  for (const rel of [".claude-plugin/plugin.json", ".cursor-plugin/plugin.json"]) {
    const target = join(p.dir, rel);
    if (!existsSync(target)) continue;
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
  for (const rel of [".claude-plugin/marketplace.json", ".cursor-plugin/marketplace.json"]) {
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
      if (JSON.stringify(existing[k]) !== JSON.stringify(projected[k])) {
        drift.push(`${relative(ROOT, target)}: ${k} out of sync`);
      }
    }
  }
  for (const p of pkgs) {
    const manifest = readJson(p.source);
    for (const rel of [".claude-plugin/plugin.json", ".cursor-plugin/plugin.json"]) {
      const target = join(p.dir, rel);
      if (!existsSync(target)) continue;
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
  for (const rel of [".claude-plugin/marketplace.json", ".cursor-plugin/marketplace.json"]) {
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
