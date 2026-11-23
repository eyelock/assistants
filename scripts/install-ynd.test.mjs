// Self-test for scripts/install-ynd.sh: it installs only an archive whose
// sha256 matches checksums.txt. A fixture release directory stands in for
// GitHub through YND_BASE_URL (file://), so nothing touches the network.
// Requires bash, tar, curl and sha256sum or shasum on PATH.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const SCRIPT = resolve(dirname(fileURLToPath(import.meta.url)), "install-ynd.sh");
const VERSION = "v9.9.9";

function platform() {
  const os = process.platform === "darwin" ? "darwin" : "linux";
  const arch = process.arch === "arm64" ? "arm64" : "amd64";
  return `${os}_${arch}`;
}

// Builds <root>/<VERSION>/{asset,checksums.txt}; `sum` overrides the recorded checksum.
function fixture({ sum, listed = true } = {}) {
  const root = mkdtempSync(join(tmpdir(), "install-ynd-"));
  const rel = join(root, VERSION);
  const stage = join(root, "stage");
  mkdirSync(rel, { recursive: true });
  mkdirSync(stage);
  writeFileSync(join(stage, "ynd"), "#!/bin/sh\necho ynd fake\n");
  const asset = `ynh_${VERSION.slice(1)}_${platform()}.tar.gz`;
  const tar = spawnSync("tar", ["-czf", join(rel, asset), "-C", stage, "ynd"]);
  assert.equal(tar.status, 0);
  const real = createHash("sha256")
    .update(readFileSync(join(rel, asset)))
    .digest("hex");
  const name = listed ? asset : "other.tar.gz";
  writeFileSync(join(rel, "checksums.txt"), `${sum ?? real}  ${name}\n`);
  return { root, bin: join(root, "bin") };
}

function run({ root, bin }) {
  return spawnSync("bash", [SCRIPT], {
    encoding: "utf8",
    env: { ...process.env, YND_VERSION: VERSION, YND_BASE_URL: `file://${root}`, BIN_DIR: bin },
  });
}

test("installs when the checksum matches", () => {
  const f = fixture();
  const r = run(f);
  assert.equal(r.status, 0, r.stderr);
  assert.ok(existsSync(join(f.bin, "ynd")));
  rmSync(f.root, { recursive: true, force: true });
});

test("fails and installs nothing on a checksum mismatch", () => {
  const f = fixture({ sum: "0".repeat(64) });
  const r = run(f);
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /checksum mismatch/);
  assert.ok(!existsSync(join(f.bin, "ynd")));
  rmSync(f.root, { recursive: true, force: true });
});

test("fails when checksums.txt does not list the archive", () => {
  const f = fixture({ listed: false });
  const r = run(f);
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /no checksum for/);
  assert.ok(!existsSync(join(f.bin, "ynd")));
  rmSync(f.root, { recursive: true, force: true });
});

test("the default version is pinned, not latest", () => {
  const text = readFileSync(SCRIPT, "utf8");
  assert.match(text, /^DEFAULT_YND_VERSION="v\d+\.\d+\.\d+"$/m);
  assert.doesNotMatch(text, /releases\/latest|gh release view/);
});
