// Odd titles, names and emails never slip past inbox.sh or break it. Each case runs the real
// inbox.sh against a small Wheelhouse, with bd replaced by a stub that keeps the arguments it was
// given: a title starting with "-" is created, not read as a flag; a merge or review named anywhere
// in the title needs --url; register refuses a command that isn't lowercase ASCII, given or
// derived; an email registered in one case is the same email in another; and an inbox bead carries
// the repo: label of the one repository it touches, which a merge or review must have.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..");
const inboxSh = join(plugin, "skills", "work-graph", "scripts", "inbox.sh");

const roster = {
  seats: [{ name: "Dalglish", group: "workers", command: "dalglish", harness: ".", mandate: "Build." }],
  humans: [
    { name: "Rook", command: "rook", pronouns: "they/them", default: true },
    { name: "Pat", command: "pat", email: "pat@example.com", pronouns: "they/them" },
  ],
};

// bd: `create` keeps its arguments, one per line, in bd-args and refuses a flag it doesn't know,
// as the real bd does; `show` knows wh-7 (labelled repo:widget) and wh-8 (no repo: label); anything
// else answers with an empty list.
const bdStub = `#!/bin/sh
if [ "$1" = create ]; then
  shift
  : > "$BD_ARGS"
  value=
  for a in "$@"; do
    printf '%s\\n' "$a" >> "$BD_ARGS"
    if [ -n "$value" ]; then value=; continue; fi
    case "$a" in
      --json) ;;
      --title | --actor | --assignee | --labels | --description | --external-ref | --deps) value=1 ;;
      -*) echo "Error: unknown flag: $a" >&2; exit 1 ;;
    esac
  done
  echo '{"id":"wh-1"}'
  exit 0
fi
if [ "$1" = show ]; then
  case "$2" in
    wh-7) echo '[{"id":"wh-7","labels":["release","repo:widget"]}]'; exit 0 ;;
    wh-8) echo '[{"id":"wh-8","labels":["release"]}]'; exit 0 ;;
    *) echo "Error: no issue $2" >&2; exit 1 ;;
  esac
fi
echo '[]'
`;

function wheelhouse() {
  const dir = mkdtempSync(join(tmpdir(), "wheelhouse-inbox-odd-"));
  mkdirSync(join(dir, "skills", "roster", "assets"), { recursive: true });
  writeFileSync(join(dir, "skills", "roster", "assets", "roster.json"), JSON.stringify(roster));
  mkdirSync(join(dir, "bin"));
  writeFileSync(join(dir, "bin", "bd"), bdStub);
  chmodSync(join(dir, "bin", "bd"), 0o755);
  return dir;
}

function inbox(args, check) {
  const dir = wheelhouse();
  try {
    const out = spawnSync("bash", [inboxSh, ...args, "--dir", "."], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, PATH: `${join(dir, "bin")}:${process.env.PATH}`, BD_ARGS: join(dir, "bd-args") },
    });
    const read = (f) => {
      try {
        return readFileSync(join(dir, f), "utf8");
      } catch {
        return null;
      }
    };
    check(out, {
      bdArgs: read("bd-args")?.split("\n").slice(0, -1) ?? null,
      roster: JSON.parse(read("skills/roster/assets/roster.json")),
    });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("assign: a title starting with '-' is created as the title, not read as a flag", () => {
  inbox(["assign", "--title", "--force the cache clear", "--from", "dalglish", "--kind", "decision"], (out, { bdArgs }) => {
    assert.equal(out.status, 0, out.stderr);
    assert.equal(JSON.parse(out.stdout).id, "wh-1");
    const i = bdArgs.indexOf("--title");
    assert.ok(i >= 0, "the title goes in with --title");
    assert.equal(bdArgs[i + 1], "--force the cache clear");
  });
});

for (const title of ["Merge: widget #13", "Please merge widget #13", "widget #13 needs a REVIEW", "Review widget #13"]) {
  test(`assign: "${title}" is a merge or review, refused without --url`, () => {
    inbox(["assign", "--title", title, "--from", "dalglish"], (out, { bdArgs }) => {
      assert.equal(out.status, 1);
      assert.match(out.stderr, /a (merge|review) needs --url/);
      assert.equal(bdArgs, null, "nothing was created");
    });
  });
}

test("assign: a merge named in the title, with --url, is labelled as a merge", () => {
  inbox(
    [
      "assign",
      "--title",
      "Please merge widget #13",
      "--from",
      "dalglish",
      "--url",
      "https://github.com/example/widget/pull/13",
      "--repo",
      "widget",
    ],
    (out, { bdArgs }) => {
      assert.equal(out.status, 0, out.stderr);
      assert.equal(JSON.parse(out.stdout).kind, "merge");
      assert.ok(bdArgs.includes("inbox:merge"));
    },
  );
});

test("assign: words that only contain merge or review are not one", () => {
  inbox(["assign", "--title", "Decide whether the merged reviewers stay", "--from", "dalglish"], (out) => {
    assert.equal(out.status, 0, out.stderr);
    assert.equal(JSON.parse(out.stdout).kind, null);
  });
});

test("assign: --kind is the switch, whatever the title says", () => {
  inbox(["assign", "--title", "Merge or not? Your call", "--from", "dalglish", "--kind", "decision"], (out) => {
    assert.equal(out.status, 0, out.stderr);
    assert.equal(JSON.parse(out.stdout).kind, "decision");
  });
});

for (const [why, args] of [
  ["a given command with a path in it", ["--name", "Gahan", "--command", "../seat/gahan"]],
  ["a given command in capitals", ["--name", "Gahan", "--command", "Gahan"]],
  ["a given command starting with '-'", ["--name", "Gahan", "--command", "-gahan"]],
  ["a name that makes the command '-'", ["--name", "-"]],
  ["a name that makes a command starting with '-'", ["--name", "-Jo"]],
]) {
  test(`register: refuses ${why}`, () => {
    inbox(["register", ...args, "--email", "gahan@example.com"], (out, { roster: after }) => {
      assert.equal(out.status, 1, out.stdout);
      assert.match(out.stderr, /is not a command|can't make a command/);
      assert.deepEqual(after, roster, "the roster is unchanged");
    });
  });
}

test("register: a name in mixed case makes a lowercase command", () => {
  inbox(["register", "--name", "Jo Ann", "--email", "jo@example.com"], (out, { roster: after }) => {
    assert.equal(out.status, 0, out.stderr);
    assert.equal(JSON.parse(out.stdout).human.command, "joann");
    assert.equal(after.humans.at(-1).command, "joann");
  });
});

test("register: an email already registered in another case is refused", () => {
  inbox(["register", "--name", "Sam", "--email", "PAT@Example.com"], (out, { roster: after }) => {
    assert.equal(out.status, 1);
    assert.match(out.stderr, /already registered, as pat/);
    assert.deepEqual(after, roster);
  });
});

test("register: the same person, with their email in another case, is already registered", () => {
  inbox(["register", "--name", "Pat", "--email", "PAT@example.com"], (out, { roster: after }) => {
    assert.equal(out.status, 0, out.stderr);
    assert.equal(JSON.parse(out.stdout).already, true);
    assert.deepEqual(after, roster);
  });
});

// ef8.12: every bead names the one repository it touches in a repo: label, inbox beads too.
const prUrl = "https://github.com/example/widget/pull/13";
const merge = ["assign", "--title", "Merge widget #13", "--from", "dalglish", "--url", prUrl];
const labels = (bdArgs) => bdArgs.filter((a, i) => bdArgs[i - 1] === "--labels");

test("assign: --repo labels the bead repo:<repo>", () => {
  inbox([...merge, "--repo", "widget"], (out, { bdArgs }) => {
    assert.equal(out.status, 0, out.stderr);
    assert.equal(JSON.parse(out.stdout).repo, "widget");
    assert.deepEqual(labels(bdArgs), ["inbox", "inbox:merge", "repo:widget"]);
  });
});

test("assign: --repo given as repo:<repo> is the same repository", () => {
  inbox([...merge, "--repo", "repo:widget"], (out, { bdArgs }) => {
    assert.equal(out.status, 0, out.stderr);
    assert.ok(labels(bdArgs).includes("repo:widget"));
  });
});

test("assign: without --repo, the bead takes the repo: label of the bead it blocks", () => {
  inbox([...merge, "--blocks", "wh-7"], (out, { bdArgs }) => {
    assert.equal(out.status, 0, out.stderr);
    assert.equal(JSON.parse(out.stdout).repo, "widget");
    assert.ok(labels(bdArgs).includes("repo:widget"));
  });
});

test("assign: --repo wins over the blocked bead's label", () => {
  inbox([...merge, "--blocks", "wh-7", "--repo", "gadget"], (out, { bdArgs }) => {
    assert.equal(out.status, 0, out.stderr);
    assert.deepEqual(labels(bdArgs), ["inbox", "inbox:merge", "repo:gadget"]);
  });
});

for (const [why, extra] of [
  ["no --repo and nothing blocked", []],
  ["no --repo and a blocked bead with no repo: label", ["--blocks", "wh-8"]],
]) {
  test(`assign: a merge is refused with ${why}`, () => {
    inbox([...merge, ...extra], (out, { bdArgs }) => {
      assert.equal(out.status, 1);
      assert.match(out.stderr, /a merge needs --repo/);
      assert.equal(bdArgs, null, "nothing was created");
    });
  });
}

test("assign: a review needs a repository too", () => {
  inbox(["assign", "--title", "Look at widget #13", "--kind", "review", "--from", "dalglish", "--url", prUrl], (out) => {
    assert.equal(out.status, 1);
    assert.match(out.stderr, /a review needs --repo/);
  });
});

test("assign: a decision that touches no repository goes unlabelled", () => {
  inbox(["assign", "--title", "Pick the release date", "--kind", "decision", "--from", "dalglish"], (out, { bdArgs }) => {
    assert.equal(out.status, 0, out.stderr);
    assert.equal(JSON.parse(out.stdout).repo, null);
    assert.ok(!labels(bdArgs).some((l) => l.startsWith("repo:")));
  });
});

for (const repo of ["widget,gadget", "../widget", "-widget", "wid get"]) {
  test(`assign: refuses --repo ${JSON.stringify(repo)}`, () => {
    inbox([...merge, "--repo", repo], (out, { bdArgs }) => {
      assert.equal(out.status, 1);
      assert.match(out.stderr, /is not a repository name/);
      assert.equal(bdArgs, null);
    });
  });
}
