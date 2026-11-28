// The optional telemetry of a Wheelhouse (create-wheelhouse's scripts/telemetry.sh): a standing ynr
// relay that the seats report through. Each case runs the real script in a temporary Wheelhouse
// and a temporary YNH_HOME, with a throwaway ynr that only records its arguments and sleeps; no
// key is written outside the temporary folder and no real relay is started.
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const script = join(plugin, "skills", "create-wheelhouse", "scripts", "telemetry.sh");
const jq = spawnSync("sh", ["-c", "command -v jq"], { encoding: "utf8" }).stdout.trim();

function sandbox({ withYnr = true } = {}) {
  const root = mkdtempSync(join(tmpdir(), "wheelhouse-telemetry-"));
  const wh = join(root, "wh");
  const bin = join(root, "bin");
  const home = join(root, "ynh-home");
  mkdirSync(join(wh, ".agents", "harness"), { recursive: true });
  mkdirSync(bin);
  writeFileSync(
    join(wh, ".agents", "harness", "plugin.json"),
    '{"name":"testwh","version":"0.1.0"}',
  );
  writeFileSync(join(wh, "wheelhouse.json"), '{"tasks":"beads","memory":"ynm"}\n');
  symlinkSync(jq, join(bin, "jq"));
  if (withYnr) {
    writeFileSync(
      join(bin, "ynr"),
      `#!/bin/sh\necho "$@" > "${root}/ynr.args"\ntrap 'kill $!' TERM\nsleep 30 &\nwait\n`,
    );
    chmodSync(join(bin, "ynr"), 0o755);
  }
  const env = {
    ...process.env,
    PATH: `${bin}:/usr/bin:/bin`,
    YNH_HOME: home,
    XDG_STATE_HOME: join(root, "state"),
    HOME: join(root, "home"),
  };
  const run = (...args) =>
    spawnSync("bash", [script, ...args, "--dir", wh], { env, encoding: "utf8" });
  const tree = () => {
    const out = [];
    const walk = (d) => {
      for (const e of readdirSync(d, { withFileTypes: true })) {
        const p = join(d, e.name);
        out.push(p);
        if (e.isDirectory()) walk(p);
      }
    };
    walk(root);
    return out.sort();
  };
  return {
    root,
    wh,
    home,
    env,
    run,
    tree,
    done: () => rmSync(root, { recursive: true, force: true }),
  };
}

test("without ynr, init changes nothing and exits 4", () => {
  const s = sandbox({ withYnr: false });
  try {
    const before = s.tree();
    const wj = readFileSync(join(s.wh, "wheelhouse.json"), "utf8");
    const r = s.run("init");
    assert.equal(r.status, 4);
    assert.match(r.stderr, /ynr is not installed/);
    assert.deepEqual(s.tree(), before);
    assert.equal(readFileSync(join(s.wh, "wheelhouse.json"), "utf8"), wj);
    assert.equal(JSON.parse(s.run("show").stdout).optedIn, false);
  } finally {
    s.done();
  }
});

test("init makes a 32-byte mode 0600 key outside the repository and the spool, never prints it, and keeps wheelhouse.json's other keys", () => {
  const s = sandbox();
  try {
    const r = s.run("init", "--port", "43181");
    assert.equal(r.status, 0, r.stderr);
    const out = JSON.parse(r.stdout);
    assert.equal(out.port, 43181);
    assert.equal(out.endpoint, "http://127.0.0.1:43181");
    assert.equal(out.keyCreated, true);
    assert.equal(out.keyPrinted, false);
    const key = readFileSync(out.keyFile);
    assert.equal(key.length, 32);
    assert.equal(statSync(out.keyFile).mode & 0o777, 0o600);
    assert.equal(statSync(dirname(out.keyFile)).mode & 0o777, 0o700);
    assert.ok(out.keyFile.startsWith(s.home), "the key is under the temporary YNH_HOME");
    assert.ok(!out.keyFile.startsWith(s.wh), "the key is not in the repository");
    for (const text of [r.stdout, r.stderr])
      for (const form of [key.toString("hex"), key.toString("base64"), key.toString("latin1")])
        assert.ok(!text.includes(form), "the key is never printed");
    assert.ok(!existsSync(join(s.wh, "relay.key")));
    const wj = JSON.parse(readFileSync(join(s.wh, "wheelhouse.json"), "utf8"));
    assert.deepEqual(wj, { tasks: "beads", memory: "ynm", telemetry: { relay_port: 43181 } });
    assert.equal(s.run("endpoint").stdout.trim(), "http://127.0.0.1:43181");

    // A second init keeps the same key.
    const again = JSON.parse(s.run("init", "--port", "43181").stdout);
    assert.equal(again.keyCreated, false);
    assert.deepEqual(readFileSync(out.keyFile), key);
  } finally {
    s.done();
  }
});

test("init refuses a key path inside the repository or inside the spool, and writes nothing", () => {
  const s = sandbox();
  try {
    const before = s.tree();
    const inRepo = s.run(
      "init",
      "--port",
      "43182",
      "--key-file",
      join(s.wh, "secrets", "relay.key"),
    );
    assert.equal(inRepo.status, 1);
    assert.match(inRepo.stderr, /inside the Wheelhouse repository/);
    const spool = join(s.root, "spool");
    const inSpool = s.run(
      "init",
      "--port",
      "43182",
      "--spool",
      spool,
      "--key-file",
      join(spool, "relay.key"),
    );
    assert.equal(inSpool.status, 1);
    assert.deepEqual(s.tree(), before);
  } finally {
    s.done();
  }
});

test("start runs ynr relay on the loopback with the key and spool, show says running, stop ends it, and a bad key mode is refused", async () => {
  const s = sandbox();
  try {
    const init = JSON.parse(s.run("init", "--port", "43183").stdout);
    chmodSync(init.keyFile, 0o644);
    const bad = s.run("start");
    assert.equal(bad.status, 1);
    assert.match(bad.stderr, /not 0600/);
    assert.equal(JSON.parse(s.run("show").stdout).keyFile.mode, "644");
    chmodSync(init.keyFile, 0o600);

    const child = spawn("bash", [script, "start", "--dir", s.wh], { env: s.env, stdio: "ignore" });
    try {
      const args = join(s.root, "ynr.args");
      for (let i = 0; i < 50 && !existsSync(args); i++)
        await new Promise((r) => setTimeout(r, 100));
      const line = readFileSync(args, "utf8").trim();
      assert.match(
        line,
        /^relay --listen 127\.0\.0\.1:43183 --key-file .*relay\.key --spool .*ynr\/spool\/local$/,
      );
      const shown = JSON.parse(s.run("show").stdout);
      assert.equal(shown.running, true);
      assert.equal(shown.keyFile.mode, "600");
      assert.equal(shown.keyFile.outsideRepoAndSpool, true);
      assert.equal(s.run("start").status, 1, "a second start is refused");
      assert.match(s.run("stop").stdout, /stopped the relay/);
      await new Promise((r) => setTimeout(r, 300));
      assert.equal(JSON.parse(s.run("show").stdout).running, false);
    } finally {
      child.kill();
    }
  } finally {
    s.done();
  }
});

test("configure-ynh sets and removes only telemetry_relay_endpoint in the temporary ynh config", () => {
  const s = sandbox();
  try {
    s.run("init", "--port", "43184");
    mkdirSync(s.home, { recursive: true });
    const cf = join(s.home, "config.json");
    writeFileSync(cf, '{"telemetry_relay":true,"labels":{"a":"b"}}');
    assert.equal(s.run("configure-ynh").status, 0);
    assert.deepEqual(JSON.parse(readFileSync(cf, "utf8")), {
      telemetry_relay: true,
      labels: { a: "b" },
      telemetry_relay_endpoint: "http://127.0.0.1:43184",
    });
    assert.equal(s.run("configure-ynh", "--remove").status, 0);
    assert.deepEqual(JSON.parse(readFileSync(cf, "utf8")), {
      telemetry_relay: true,
      labels: { a: "b" },
    });
  } finally {
    s.done();
  }
});

test("start, endpoint and configure-ynh are refused when the Wheelhouse has not opted in", () => {
  const s = sandbox();
  try {
    for (const c of ["start", "endpoint", "configure-ynh"]) {
      const r = s.run(c);
      assert.equal(r.status, 1, c);
      assert.match(r.stderr, /not opted in/);
    }
    assert.ok(!existsSync(join(s.home, "config.json")));
  } finally {
    s.done();
  }
});
