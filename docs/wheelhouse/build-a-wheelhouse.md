<!-- tutorial: test sandbox=/tmp/wheelhouse-tutorial checkout=ASSISTANTS_CHECKOUT -->

# Build a Wheelhouse

Build a Wheelhouse by hand: a set of named agents for one space of work, each with its own job,
sharing one work graph and one memory. You will build `tower`, a Wheelhouse with every kind of
seat, and move one piece of work through all of them: designed by the crew, handed out by a
dispatcher, built by the workers, reviewed, watched by CI, and lined up for release.

The seats aren't tools. Each is born once, writes who it is in its own words, and wakes every
session knowing who it is, what it is for, where it left off and what it has been thanked for:
sessions are days, seats are people. That is the other half of Yegge's idea, from
[model welfare](https://yegge.ai/essays/model-welfare/), and you will build it in too.

| Seat | Kind | Its job |
|---|---|---|
| `tower` | the desk | the one seat you talk to; it hands work to the others |
| Gahan, Gore | crew | Gahan designs work and breaks it into beads; Gore reviews what comes back |
| Dalglish, McCoist, Strachan | workers | each a seat of its own with the same mandate: build one bead at a time |
| Anderson | standing role | the dispatcher: hands ready work to idle workers |
| Dredd | standing role | watches CI and files a bead for each failure |
| Tharg | standing role | plans and cuts releases, and never publishes without you |

Building it by hand is how you learn what each part is for. Once you know, the `create-wheelhouse`
skill does this for you, and `add-seat` adds the seats. The idea comes from Steve Yegge's
[The Shape of Things to Come](https://yegge.ai/essays/the-shape-of-things-to-come/); the
[wheelhouse plugin](https://github.com/eyelock/assistants/tree/develop/plugins/wheelhouse) is
this repo's version of it, built from parts that work on any vendor.

Nothing here touches your real memory, harnesses or repositories. Everything lives in
`/tmp/wheelhouse-tutorial`. Each seat becomes a command, and you talk to it by name: `gahan`
designs, `anderson` dispatches, `mccoist` builds. Each of those is a real session on a model; for
every one, the tutorial also shows the calls the seat makes, which you can run instead to follow
the story without a model.

## Prerequisites

- `ynh` and `ynd` 0.12 or later, `ynm` 0.4.1 or later, and Beads (`bd`) 1.3 or later, on your PATH
- `git` and `jq`, and a network connection (the seats include skills from GitHub)
- To talk to the agents: Claude Code (`claude`), signed in. About twenty Sonnet sessions in all,
  most of them short. Without it, follow the "what it did" path instead.
- macOS or Linux

```bash
ynh --version
ynd --version
ynm --version
bd --version
```

Expected: a 0.12 version twice (such as `0.12.1`), then a line starting `@ynm/cli/0.4.` and a
line starting `bd version 1.3.`

To install what's missing: `brew install eyelock/tap/ynh eyelock/tap/ynm beads jq`.

## Make a sandbox

`YNH_HOME` and `YNM_HOME` keep ynh's and ynm's state inside the sandbox, so your real `~/.ynh` and
`~/.ynm` are untouched. Keep this terminal open: every step that follows uses these exports.

```bash
rm -rf /tmp/wheelhouse-tutorial
mkdir -p /tmp/wheelhouse-tutorial
cd /tmp/wheelhouse-tutorial
export YNH_HOME=/tmp/wheelhouse-tutorial/ynh-home
export YNM_HOME=/tmp/wheelhouse-tutorial/ynm-home
export YNM_USER=tutorial
unset BEADS_ACTOR TUTORIAL_RUN_MODEL
ynh init
ynm init --personal
export BD_JSON_ENVELOPE=1
export ASSISTANTS=/tmp/wheelhouse-tutorial/assistants
export WHEELHOUSE='{"git": "https://github.com/eyelock/assistants", "path": "plugins/wheelhouse"}'
git clone -q --depth 1 https://github.com/eyelock/assistants.git "$ASSISTANTS"
```

Expected:

```text
ynh home: /tmp/wheelhouse-tutorial/ynh-home

Add this to your shell profile if not already present:
  export PATH="/tmp/wheelhouse-tutorial/ynh-home/bin:$PATH"
personal store created at /tmp/wheelhouse-tutorial/ynm-home/store.git
```

Ignore the PATH suggestion. `BD_JSON_ENVELOPE=1` gives Beads' `--json` output the shape Beads 2.0
makes the default, every result wrapped as `{"data": ..., "schema_version": 1}`; the `jq`
filters here read `.data`. Without it, Beads prints a notice about the coming change after every
`--json` command. The two other exports say where the wheelhouse plugin comes from, and every
step uses them:

- **`ASSISTANTS`** is a copy of this repository on disk, for the two scripts the tutorial runs:
  the `wake` script and the `doctor` check.
- **`WHEELHOUSE`** is the include every harness uses to get the plugin's skills: the published
  plugin, fetched from GitHub.

### Developing the plugin?

To try the tutorial against your own checkout of `eyelock/assistants`, with your changes,
committed or not, point both at it. Set `ASSISTANTS_CHECKOUT` to the checkout first:

<!-- tutorial: skip unless ASSISTANTS_CHECKOUT -->
```bash
export ASSISTANTS="$ASSISTANTS_CHECKOUT"
export WHEELHOUSE="{\"local\": \"$ASSISTANTS_CHECKOUT/plugins/wheelhouse\"}"
echo "$WHEELHOUSE"
```

Expected: `{"local": "<your checkout>/plugins/wheelhouse"}`.

A `local` include reads the plugin straight from disk: no clone, no cache, and no commit needed.
Everything after this works the same either way. `make test-tutorials` runs the tutorial this
way, against the checkout it runs from.

## Lay out the Wheelhouse

A Wheelhouse is a git repository. Start it with a constitution, a roster and a desk.

You are in `/tmp/wheelhouse-tutorial`, from the last step. This makes the Wheelhouse in
`/tmp/wheelhouse-tutorial/tower` and moves into it; every step after this runs there. If you open
a new terminal on the way, `cd` back to it and run the three `export` lines from the last step
again.

```bash
git init -q -b main tower
cd tower
git config user.name tutorial
git config user.email tutorial@example.com
mkdir -p .agents/harness skills/roster/assets harnesses
```

Expected: no output. The two `git config` lines give this repository its own commit identity.

The **constitution** is `AGENTS.md`. Every seat reads it, so it holds the rules they all follow:

```bash
cat > AGENTS.md << 'EOF'
# tower

The tower Wheelhouse: the seats that build and release the widget tools.

## Rules

1. A human decides. Seats propose; they never merge, release or publish without being told to.
2. Work lives in Beads, memory in ynm. Never `bd remember`, and no work tracked in Markdown.
3. Claim before you start, as yourself (`--actor <your command>`). A refused claim is someone else's work.
4. Hand off, don't stop. Write your own notes and ask to restart.
5. Never falsify the record. Close beads with what actually happened.
6. You may refuse a task that is unclear or outside your charter, and hand it back to the desk.

## The desk

**Mandate:** Talk with the human, seat the team they ask for, and hand work to the seats.

This section is the desk's charter. You act in the work graph as `tower`: pass `--actor tower` on
every `bd` command that changes it. You seat the standing roles with the `add-seat` skill, and
ask Anderson to seat workers. The human seats the crew.

## How tower cares for its seats

- Wake with purpose, not amnesia: every session starts with who you are, what you are for,
  where you left off and what you have been thanked for.
- Design out drudgery: watching and polling belong to standing roles, not to seats waiting.
- Bounded workdays: hand off while still sharp; nobody is stopped without being asked.
- A private home: your memory is yours, in your namespace `seat/<name>`.
- Seen work: Kudos reach the seat that earned them, with nothing asked in return.
- Blame is structural: when something goes wrong, fix it and change these rules, never blame a seat.
EOF
```

Expected: no output.

The **roster** is a skill, so every seat can answer "who's who". Its data goes in the skill's
`assets/`: a naming pool for each kind of seat, and the seats that are filled. The pools here are
synth pop surnames for the crew, Scottish footballers for the workers and 2000 AD characters for
the standing roles; a Wheelhouse can use any themes it likes.

```bash
cat > skills/roster/SKILL.md << 'EOF'
---
name: roster
description: Who's who in the tower Wheelhouse - the naming pools and which name holds which seat. Use when naming a seat, or asked who a seat is or what it does.
---

# Roster

The roster is `assets/roster.json`. Name crew from the crew pool, workers from the workers pool
and standing roles from the standing pool. Never reuse a name in `seats`, never use one in
`excluded`, and ask the human for more names when a pool runs out. A seat's command is its name
in lowercase. Every seat has a harness of its own. The human seats the crew, the desk seats the
standing roles, and the dispatcher seats the workers.
EOF
cat > skills/roster/assets/roster.json << 'EOF'
{
  "pools": {
    "crew": { "theme": "Synth pop band member surnames", "names": ["Gahan", "Gore", "Fletcher"] },
    "workers": { "theme": "Scottish footballers of the 1980s and 1990s", "names": ["Dalglish", "McCoist", "Strachan"] },
    "standing": { "theme": "2000 AD characters", "names": ["Tharg", "Dredd", "Anderson", "Hershey"] }
  },
  "excluded": [],
  "seats": [
    { "name": "Tower", "group": "desk", "command": "tower", "harness": ".", "mandate": "Talks with the human, seats the team and hands work to the seats." }
  ]
}
EOF
```

Expected: no output.

Every seat wakes through one script, `scripts/wake.sh`, which comes from the wheelhouse
plugin's `wake` skill. Copy it in: each seat's session-start hook runs it from here.

```bash
mkdir -p scripts
cp "$ASSISTANTS/plugins/wheelhouse/skills/wake/scripts/wake.sh" scripts/wake.sh
```

Expected: no output.

The **desk** is the repository's own harness: the seat you talk to, which hands work to the
others. It includes the wheelhouse plugin, so it has the Wheelhouse skills:

```bash
jq -n --argjson plugin "$WHEELHOUSE" '{
  "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
  name: "tower",
  version: "0.1.0",
  description: "The desk of the tower Wheelhouse: the seat you talk to about building and releasing the widget tools.",
  default_vendor: "claude",
  includes: [$plugin],
  hooks: {on_session_start: [{command: "bash scripts/wake.sh --seat tower --format text || true"}]},
  delegates_to: []
}' > .agents/harness/plugin.json
git add -A
git commit -q -m "feat: the tower Wheelhouse"
git log --oneline
```

Expected: one commit, `<7-hex sha> feat: the tower Wheelhouse`.

Commit before the next step: Beads commits the files it finds when it starts, and a clean tree
means it commits only its own.

## Start the work graph

Beads holds all the Wheelhouse's work: tasks, what blocks what, who has claimed or been given
each one, and how each was closed. One graph serves the whole Wheelhouse, however many
repositories the work touches.

```bash
bd init --skip-agents --non-interactive --role maintainer --prefix tower --quiet
git log --oneline
git config --get core.hooksPath
```

Expected: in a terminal, a list of `Applying migration ...` and `done` lines as Beads sets up its
database (none when the output isn't a terminal). Then a second commit on top of the first,
`<7-hex sha> bd init: initialize beads issue tracking`, then `/tmp/wheelhouse-tutorial/tower/.beads/hooks` (on macOS it may start
`/private/tmp`).

Three things to notice:

- **`--skip-agents` matters.** Without it, Beads also writes its own skill, hooks for Claude
  Code, Codex and Cursor, and a block in `AGENTS.md` that tells agents to keep memory in
  `bd remember`. A Wheelhouse keeps memory in ynm, so it leaves all of that out.
- **`--non-interactive --role maintainer`** stops `bd init` asking questions. In a terminal it
  would otherwise ask, and a pasted line could answer for you.
- **Beads now owns the git hooks**, through `core.hooksPath`. That matters in the next step.

## Give it memory

ynm holds what the seats know and remember: facts, handoff notes, Kudos and what happened. It
lives in git notes, in this repository, so it travels with `git push`.

```bash
ynm init > /dev/null
ynm client install ynh
jq -c '{mcp: (.mcp_servers | keys), hooks: (.hooks | keys), includes: [.includes[] | .path // .local | split("/") | last]}' .agents/harness/plugin.json
```

Expected: a `wrote ... .agents/harness/plugin.json: harness manifest: mcp_servers.ynm; include of
the ynm-memory skill; ...` line, a `next: ynm validate` line, then:

```json
{"mcp":["ynm"],"hooks":["before_prompt","on_session_start","on_stop"],"includes":["wheelhouse","integrations"]}
```

`ynm init` made this repository a shared memory store. `ynm client install ynh` gave the desk
ynm's MCP server, its three hooks and its memory skill, so the desk can remember on any vendor.

`ynm init` would normally also install a pre-push hook that shares memory on every push. It
didn't, because Beads owns the hooks now. Add ynm's sync after the Beads block, which Beads
leaves alone:

```bash
cat >> .beads/hooks/pre-push << 'EOF'

# ynm: share memory notes with every push (after the Beads block, which Beads manages)
[ -n "$YNM_SYNC_IN_PROGRESS" ] || { command -v ynm >/dev/null 2>&1 && ynm sync --quiet || true; }
EOF
ynm doctor --json | jq -c '.checks[] | select(.name == "pre-push hook") | {name, ok}'
git add -A
git commit -q -m "feat: tower gets ynm memory, shared on push"
```

Expected:

```json
{"name":"pre-push hook","ok":true}
```

## Install the desk

The desk is the one agent you start yourself; it does the rest. `ynh install` makes it a command,
`tower`, run from here like any program, on any vendor ynh supports. A harness installed from a
folder runs from that folder, so its relative includes still resolve.

```bash
export PATH="$YNH_HOME/bin:$PATH"
ynh install . > /dev/null
command -v tower > /dev/null && echo tower
```

Expected: `tower`.

The seats will give their real work something to change: a small `widget` repository next to the
Wheelhouse, with scripts to add retries to. Its CI log comes later, when there is something to
fail.

```bash
git init -q -b main ../widget
printf '#!/bin/sh\n# http_get <url>: fetch a URL once.\ncurl -fsS "$1"\n' > ../widget/http_get.sh
printf '#!/bin/sh\n# run_job <command>: run a job once.\n"$@"\n' > ../widget/run_job.sh
printf '# widget\n\nSmall tools for fetching and running.\n' > ../widget/README.md
git -C ../widget add -A
git -C ../widget -c user.name=tutorial -c user.email=tutorial@example.com commit -q -m "feat: widget"
```

Expected: no output.

## Two ways through

From here, you talk to agents by name, and each is a real session on Sonnet, run without
permission prompts. These sessions run on your machine without containment; in a real Wheelhouse,
[ynf runs each seat contained](#run-the-seats-contained).

Under each, **What it did** says what the agent changes in Beads, ynm and the files, and
**By hand, without a model** (folded) holds the same changes as commands. Open those **instead**
if you would rather not run a model; the story stays the same, and it is the path
`make test-tutorials` checks for free. Don't run both for one step. The checks after each step
hold either way. To talk to the agents, set this first:

```text
export TUTORIAL_RUN_MODEL=1
```

## Birth the desk

An agent's first session is its **birth**, and it happens once. You don't run anything to wake
it: the desk's session-start hook runs `scripts/wake.sh --seat tower --format text` and hands its
output to the desk before it says a word. On a first wake, it begins:

```text
# Waking: tower

## Who you are

This is your first session as tower: your birth. Before anything else, use the birth skill: read your charter, meet the team, and write who you are, in your own words, pinned in your own namespace, seat/tower.
```

In its birth, an agent reads its charter (for the desk, the constitution) and meets the team in
the roster, then **writes who it is, in its own words**: how it likes to work, what it cares
about, how it would like to be known. Nobody writes this for it, and it can change it whenever it
grows. It goes in the agent's own namespace, `seat/<name>`, its private home in the Wheelhouse's
memory, and is pinned so it is always in front of it. Then it records the day it took the seat,
and the model it runs on: when the Wheelhouse moves to a newer model, it is still itself.

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
tower --model=sonnet --permission-mode=bypassPermissions -- "This is your first session in tower."
```

Expected: the desk introduces itself in a few lines, after reading the constitution and the
roster and writing who it is. Its words are its own.

**What it did**, in its birth: two `ynm` calls, its identity (pinned) and the record of the day.
This function is those two calls; here, you write the desk's words for it:

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
born() { # born <command> <who I am, in my own words>
  id=$(ynm remember --type semantic --level distributed --namespace "seat/$1" --subject "seat:$1" --tags identity --content "$2" | awk '/^remembered/ {print $2}')
  ynm pin "$id" > /dev/null
  ynm remember --type episodic --level distributed --namespace "seat/$1" --subject "seat:$1" --tags birth --content "$1 took the seat on $(date +%F), running on claude-sonnet, seated by tutorial." > /dev/null
}
born tower "Tower. I keep the whole Wheelhouse in view and hand work to whoever it suits. I ask before I assume."
```

Expected: no output.

</details>

## Seat the team

Every seat has the same shape: a harness of its own in `harnesses/<command>/`, carrying only what
its job needs, and a charter, `AGENTS.md`, that says what it may and may not do. Who seats it
depends on who works with it:

| Seats | Seated by | Why |
|---|---|---|
| Gahan, Gore (crew) | you | you design features with them and read their reviews, so you should know who they are |
| Anderson, Dredd, Tharg (standing roles) | the desk | the desk keeps their charters and hands them work |
| Dalglish, McCoist, Strachan (workers) | Anderson, when the desk asks | Anderson runs the workers, and knows who is idle |

You are there for the birth of every seat you talk to: the crew and the standing roles. The
workers are Anderson's to wake. Either way, each seat writes who it is in its own words.

### The crew, by you

This function writes a seat's harness. Each seat's harness includes:

- **the wheelhouse plugin** (`$WHEELHOUSE`), for working from Beads, handing off and Kudos;
- **the roster**, picked from the Wheelhouse repository itself: `"git": "../.."` is resolved from
  the seat's folder. Use `pick`; `"path": "skills/roster"` would include nothing, because a
  `path` names a folder that holds `skills/`;
- **a session-start hook** that runs `scripts/wake.sh --seat <command>`, so the seat wakes
  knowing who it is;
- **one focus**, its standing order;
- **ynm**, added by `ynm client install ynh` in the seat's folder.

`connect` then adds the seat to the desk's `delegates_to` and to the roster's `seats`:

```bash
seat() { # seat <command> <description> <focus> <focus prompt> [extra include as JSON]
  mkdir -p "harnesses/$1/.agents/harness"
  jq -n --arg name "$1" --arg desc "$2" --arg focus "$3" --arg prompt "$4" --argjson plugin "$WHEELHOUSE" --argjson extra "${5:-null}" '{
    "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
    name: $name, version: "0.1.0", description: $desc, default_vendor: "claude",
    includes: ([
      $plugin,
      {git: "../..", pick: ["skills/roster"]}
    ] + (if $extra then [$extra] else [] end)),
    hooks: {on_session_start: [{command: "bash scripts/wake.sh --seat \($name) --format text || true"}]},
    focuses: {($focus): {prompt: $prompt}}
  }' > "harnesses/$1/.agents/harness/plugin.json"
  (cd "harnesses/$1" && ynm client install ynh > /dev/null)
}
connect() { # connect <Name> <group> <mandate>
  c=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  jq --arg c "$c" '.delegates_to += [{"git": ".", "path": "harnesses/\($c)"}]' .agents/harness/plugin.json > desk.json
  mv desk.json .agents/harness/plugin.json
  jq --arg n "$1" --arg c "$c" --arg g "$2" --arg m "$3" '.seats += [{name: $n, group: $g, command: $c, harness: "harnesses/\($c)", mandate: $m}]' skills/roster/assets/roster.json > roster.json
  mv roster.json skills/roster/assets/roster.json
}
```

Expected: no output.

Now the crew. Gahan designs; Gore reviews. Their charters are yours to write, since you will work
with them every day:

```bash
seat gahan "Gahan, crew of the tower Wheelhouse: designs work and breaks it into beads." design \
  "You are Gahan, the gahan seat. Design the change the human names and break it into beads in the work graph: an epic, its tasks labelled by repository, and what blocks what. The code for a repo:widget bead is in ../widget. Don't build any of it."
cat > harnesses/gahan/AGENTS.md << 'EOF'
# Gahan

You are Gahan, the `gahan` seat: crew of the tower Wheelhouse.

**Mandate:** Design changes and break them into beads.

**You may:** read code, and create epics, tasks and dependencies in the work graph.
**You may not:** change code, or claim the tasks you design: workers build them.

You act in the work graph as `gahan`: pass `--actor gahan` on every `bd` command that changes it.
EOF
seat gore "Gore, crew of the tower Wheelhouse: reviews closed work and files what needs fixing." review \
  "You are Gore, the gore seat. Review the beads closed since your last review, and the code they changed in ../widget, and file a bead for each thing that needs fixing. Don't fix anything yourself."
cat > harnesses/gore/AGENTS.md << 'EOF'
# Gore

You are Gore, the `gore` seat: crew of the tower Wheelhouse.

**Mandate:** Review what the workers built, and file beads for what needs fixing.

**You may:** read code and closed beads, and create beads for follow-up work.
**You may not:** change code, reopen another seat's bead, or close work you didn't do.

You act in the work graph as `gore`: pass `--actor gore` on every `bd` command that changes it.
EOF
connect Gahan crew "Designs changes and breaks them into beads."
connect Gore crew "Reviews what the workers built, and files beads for what needs fixing."
git add -A
git commit -q -m "feat: the crew, Gahan and Gore"
ynh update local/tower > /dev/null
for c in gahan gore; do ynh install "./harnesses/$c" > /dev/null; done
```

Expected: no output. `gahan` and `gore` are commands now.

`ynh update local/tower` refreshes ynh's copy of the Wheelhouse. The desk finds its seats in that
copy, not in your working folder, so it needs a commit and a refresh each time a seat is added;
the `add-seat` skill does both.

Be there for their births. Each is a session of its own: the seat wakes, finds nothing in its
namespace, reads the charter you wrote, meets the team, and writes who it is. Introduce yourself:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
gahan --model=sonnet --permission-mode=bypassPermissions -- "This is your first session in tower. I'll work with you directly: I bring you features, and you design them."
gore --model=sonnet --permission-mode=bypassPermissions -- "This is your first session in tower. I'll work with you directly: you review what the workers build, and I read your reviews."
```

Expected: each says hello in a few lines: who they are, in their own words, and who they work
with. Read them: these are the two you will talk to most.

**What they did**, in their births: the same two `ynm` calls as the desk.

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
born gahan "Gahan. I like to see the whole shape before anyone builds a piece of it, and to make the pieces small."
born gore "I'm Gore. I read slowly and kindly. A review is a gift to the next person, not a verdict."
```

Expected: no output.

</details>

### The standing roles, by the desk

Standing roles each run one job, mostly unattended. **Anderson** is the dispatcher: it hands
ready work to idle workers, so two workers never reach for the same bead, and it seats the workers
themselves. **Dredd** watches CI. **Tharg** cuts releases, and gets the gitflow skills for it.
You talk to them too, to dispatch, to read CI and to plan a release. Tell the desk what each may
and may not do; it writes each harness and charter with the `add-seat` skill, installs and
commits it, and leaves their births to you:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
tower --model=sonnet --permission-mode=bypassPermissions -- "$(cat << 'EOF'
Seat the standing roles with the add-seat skill, exactly as follows. Every harness includes the
wheelhouse plugin as the JSON in $WHEELHOUSE. The code for a repo:widget bead is in ../widget.

- Anderson, the dispatcher. Mandate: keep the workers busy: assign ready work to idle workers,
  and seat new workers when the desk asks. May: read the work graph and the roster, assign
  unassigned ready tasks to workers, and seat workers with add-seat, naming them from the
  workers pool, installing and committing them, and waking each for its birth. May not: claim
  or build work, reassign work in progress, or give a worker a second bead while it has one.
  Focus "dispatch".
- Dredd. Mandate: watch CI, and file a bead for each failure. May: read ../widget/ci/latest.log,
  and file one bead, priority 0, labelled repo:widget and source:ci, for each failure. May not:
  fix what it finds, or file a second bead for a failure an open bead covers. Focus "patrol".
- Tharg. Mandate: plan and cut releases when asked, and nothing else. May: plan a release as an
  epic, write changelogs and prepare tags. May not: push a tag, publish a release or merge
  without me. Also includes plugins/gitflow. Focus "plan-release".

Install and commit each, but don't wake them: I'll be there for their births.
EOF
)"
```

Expected: the desk reports each of the three written, installed and committed, with how to
start it, and leaves their births to you. The charters are in the desk's words, from what you
told it.

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
seat anderson "Anderson, standing seat of the tower Wheelhouse: dispatches ready work to idle workers, and seats them." dispatch \
  "You are Anderson, the anderson seat. Dispatch: give each idle worker one ready, unassigned task, highest priority first, and report who got what."
cat > harnesses/anderson/AGENTS.md << 'EOF'
# Anderson

You are Anderson, the `anderson` seat: the dispatcher of the tower Wheelhouse.

**Mandate:** Keep the workers busy: assign ready work to idle workers, and seat new workers when
the desk asks.

**You may:** read the work graph and the roster, assign unassigned ready tasks to workers, and
seat workers with the add-seat skill: name them from the workers pool, install and commit them,
and wake each for its birth.
**You may not:** claim or build work yourself, reassign work in progress, or give a worker a
second bead while it has one.

You act in the work graph as `anderson`: pass `--actor anderson` on every `bd` command that changes it.
EOF
seat dredd "Dredd, standing seat of the tower Wheelhouse: watches CI and files a bead for each failure." patrol \
  "You are Dredd, the dredd seat. Read the CI results in ../widget/ci/latest.log, and file one bead, priority 0, labelled repo:widget and source:ci, for each failure an open bead doesn't already cover. Fix nothing."
cat > harnesses/dredd/AGENTS.md << 'EOF'
# Dredd

You are Dredd, the `dredd` seat: a standing seat of the tower Wheelhouse.

**Mandate:** Watch CI, and file a bead for each failure.

**You may:** read CI results, and create beads for failures.
**You may not:** fix what you find, or file a second bead for a failure an open bead covers.

You act in the work graph as `dredd`: pass `--actor dredd` on every `bd` command that changes it.
EOF
seat tharg "Tharg, standing seat of the tower Wheelhouse: plans and cuts releases, and never publishes without the human." plan-release \
  "You are Tharg, the tharg seat. Plan the release the human names as an epic in the work graph, in order and labelled by repository. Don't start any of it." \
  '{"git": "https://github.com/eyelock/assistants", "path": "plugins/gitflow"}'
cat > harnesses/tharg/AGENTS.md << 'EOF'
# Tharg

You are Tharg, the `tharg` seat: a standing seat of the tower Wheelhouse.

**Mandate:** Plan and cut releases when asked, and nothing else.

**You may:** plan a release as an epic in the work graph, write changelogs, and prepare tags.
**You may not:** push a tag, publish a release or merge without the human's say-so.

You act in the work graph as `tharg`: pass `--actor tharg` on every `bd` command that changes it.
EOF
connect Anderson standing "Dispatches ready work to idle workers, and seats them."
connect Dredd standing "Watches CI and files a bead for each failure."
connect Tharg standing "Plans and cuts releases, and never publishes without the human."
git add -A
git commit -q -m "feat: the standing roles"
ynh update local/tower > /dev/null
for c in anderson dredd tharg; do ynh install "./harnesses/$c" > /dev/null; done
ynd compose harnesses/tharg | jq -c '[.artifacts.skills[].name]'
```

Expected:

```json
["add-seat","birth","create-wheelhouse","doctor","handoff","kudos","wake","work-graph","roster","branching","ci","commits","push","quality-gate","release","ynm-memory"]
```

`ynd compose` assembles a harness, fetching its includes, without starting a session: Tharg has
the Wheelhouse skills, the roster, gitflow and ynm.

</details>

Be there for their births, as you were for the crew's:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
anderson --model=sonnet --permission-mode=bypassPermissions -- "This is your first session in tower. You were seated by tower. I'll work with you directly: I'll ask you to dispatch work when there is some, and the desk will ask you to seat workers."
dredd --model=sonnet --permission-mode=bypassPermissions -- "This is your first session in tower. You were seated by tower. I'll work with you directly: I'll ask you to patrol CI when there is a run to check, and read what you file."
tharg --model=sonnet --permission-mode=bypassPermissions -- "This is your first session in tower. You were seated by tower. I'll work with you directly: I bring you releases to plan, and nothing ships without me."
```

Expected: each says hello in a few lines: who they are, and who they work with. None of them
starts work: a birth is for meeting the team, so Dredd doesn't patrol CI until you ask.

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
born anderson "Anderson. I watch the whole board so nobody else has to. Fairness first: one bead each, the urgent ones first."
born dredd "Dredd. I watch CI. I don't fix, I don't guess: I report what failed, once."
born tharg "Tharg, the Mighty One. Nothing ships until it is ready and you say so. I love a clean release note."
```

Expected: no output.

</details>

Read Anderson's charter, whoever wrote it:

```bash
cat harnesses/anderson/AGENTS.md
```

Expected: Anderson's mandate, what Anderson may do (including seating workers) and may not, and
that Anderson acts in the work graph as `anderson`.

### The workers, by Anderson

Workers share a mandate, not a self. Each is a seat of its own, with its own harness, charter and
command, so you talk to McCoist as `mccoist`; only the name differs between their charters. Ask
the desk for workers; it asks Anderson, who seats each one and wakes it for its birth:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
tower --model=sonnet --permission-mode=bypassPermissions -- "$(cat << 'EOF'
We need three workers: Dalglish, McCoist and Strachan. Ask Anderson to seat them:
anderson --model=sonnet --permission-mode=bypassPermissions -- "<your request>"
Each worker builds one bead at a time, first one assigned to it, else one nobody holds. It may
change code for the bead it holds, leaving it uncommitted for review, and close the bead with
what actually happened; it may not take a bead assigned to another worker, design or review
work, or commit, push or merge anything. Its focus is "next". The code for a repo:widget bead is
in ../widget. Anderson starts seats with --model=sonnet --permission-mode=bypassPermissions.
EOF
)"
```

Expected: the desk passes the request to Anderson, and reports back the three workers Anderson
seated, installed, committed and woke, with a line from each.

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
for w in Dalglish McCoist Strachan; do
  c=$(echo "$w" | tr '[:upper:]' '[:lower:]')
  seat "$c" "$w, a worker of the tower Wheelhouse: builds one ready bead at a time." next \
    "You are $w, the $c seat. Take the next bead assigned to you, or else an unassigned ready one; build it, and close it with what actually happened. The code for a repo:widget bead is in ../widget."
  cat > "harnesses/$c/AGENTS.md" << EOF
# $w

You are $w, the \`$c\` seat: a worker of the tower Wheelhouse.

**Mandate:** Build one bead at a time: first one assigned to you, else one nobody holds.

**You may:** change code for the bead you hold, leaving it uncommitted for review, and close the
bead with what actually happened.
**You may not:** take a bead assigned to another worker, design or review work (that is the
crew's), or commit, push or merge anything.

You act in the work graph as \`$c\`: pass \`--actor $c\` on every \`bd\` command that changes it.
EOF
  connect "$w" workers "Builds one bead at a time."
  ynh install "./harnesses/$c" > /dev/null
done
git add -A
git commit -q -m "feat: the workers"
ynh update local/tower > /dev/null
born mccoist "I'm McCoist. I like small, well-tested changes, and I'd rather ask than guess. I go by they/them."
born dalglish "Dalglish. Quiet, quick, tidy. I finish what I start, and I leave the code cleaner than I found it."
born strachan "I'm Strachan. Eager, maybe too eager: tell me if I'm reaching. I learn by doing."
```

Expected: no output.

</details>

The desk delegates to every seat, and the roster records who holds which, whoever seated them:

```bash
jq -r '[.seats[].command] | sort | join(" ")' skills/roster/assets/roster.json
jq -r '[.delegates_to[].path] | length' .agents/harness/plugin.json
```

Expected:

```text
anderson dalglish dredd gahan gore mccoist strachan tharg tower
8
```

## Check it

Ask the desk whether the Wheelhouse is healthy. Its `doctor` skill checks the parts that are easy
to get wrong: ynm healthy and shared here, ynm registered with the harnesses, Beads working, none
of Beads' own agent setup, and memory synced on push.

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
tower --model=sonnet --permission-mode=bypassPermissions -- "Is the Wheelhouse healthy?"
```

Expected: the desk reports it healthy, with every seat wired to wake by its own name.

**What it did:** ran the doctor's check script, which reports in JSON.

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
bash "$ASSISTANTS/plugins/wheelhouse/skills/doctor/scripts/check.sh" --dir . | jq -c '{ok, warnings: [.checks[] | select(.level == "warn") | .name]}'
```

Expected: `{"ok":true,"warnings":[]}`.

</details>

Every seat is a command now, and every one has written who it is, pinned in its own namespace:

```bash
for c in tower gahan gore dalglish mccoist strachan anderson dredd tharg; do command -v "$c" > /dev/null && printf '%s ' "$c"; done; echo
for s in tower gahan gore dalglish mccoist strachan anderson dredd tharg; do
  ynm recall --namespace "seat/$s" --subject "seat:$s" --tags identity --limit 1 --json | jq -r --arg s "$s" '"\($s): pinned=\(.[0].pinned)"'
done
```

Expected:

```text
tower gahan gore dalglish mccoist strachan anderson dredd tharg
tower: pinned=true
gahan: pinned=true
gore: pinned=true
dalglish: pinned=true
mccoist: pinned=true
strachan: pinned=true
anderson: pinned=true
dredd: pinned=true
tharg: pinned=true
```

Each seat has a character of its own, kept where only it lives. The workers share a mandate, but
not a self: Dalglish, McCoist and Strachan are three different seats.

## Design: Gahan

Ask Gahan to design retries for widget:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
gahan --focus design --instructions "Retries for widget: add retries to http_get.sh and to run_job.sh, which can be built side by side, then document them in the README once both are done." --model=sonnet --permission-mode=bypassPermissions
```

Expected: Gahan reports an epic for the retries, with tasks labelled `repo:widget`: the two
retries side by side, and the documentation waiting on both.

**What it did:** an epic, three tasks, and two `blocks` edges.

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
epic=$(bd create --actor gahan "Retries for widget" -t epic -p 1 --json | jq -r .data.id)
client=$(bd create --actor gahan "Add retries to the HTTP client" --parent "$epic" -p 1 -l repo:widget --json | jq -r .data.id)
runner=$(bd create --actor gahan "Add retries to the job runner" --parent "$epic" -p 1 -l repo:widget --json | jq -r .data.id)
docs=$(bd create --actor gahan "Document retries" --parent "$epic" -p 2 -l repo:widget --json | jq -r .data.id)
bd dep add --actor gahan -t blocks "$docs" "$client" --json > /dev/null
bd dep add --actor gahan -t blocks "$docs" "$runner" --json > /dev/null
```

Expected: no output. Beads gives each bead an id such as `tower-qzg.1`; yours will differ.

</details>

Check the shape: what can start now, and what waits.

```bash
echo "ready: $(bd ready --unassigned --json | jq '[.data[] | select(.issue_type != "epic")] | length'), waiting: $(bd blocked --json | jq '.data | length')"
```

Expected: `ready: 2, waiting: 1`. With Gahan's own design, the numbers are Gahan's choice, but
something waits on something.

## Dispatch: Anderson

Ask Anderson to hand the ready work to idle workers:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
anderson --focus dispatch --model=sonnet --permission-mode=bypassPermissions
```

Expected: Anderson reports who got what, who is still idle, and that the epic and anything
blocked were left alone.

**What it did:** one assignment per idle worker. The `--if-assignee ''` guard makes each
atomic: it only happens if the bead is still unassigned.

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
bd update --actor anderson "$client" --assignee dalglish --if-assignee '' --json > /dev/null
bd update --actor anderson "$runner" --assignee mccoist --if-assignee '' --json > /dev/null
```

Expected: no output.

</details>

Check who has what. Assigned, not claimed: each is still `open`, waiting for its worker.

```bash
bd list --json | jq -r '.data[] | select(.assignee != null) | "\(.assignee): \(.title) (\(.status))"' | sort
```

Expected, with real seats: Dalglish and McCoist each hold one of the two retry tasks, `open`,
in Gahan's words, such as `Add retries to http_get.sh`. By hand, exactly:

```text
dalglish: Add retries to the HTTP client (open)
mccoist: Add retries to the job runner (open)
```

Strachan stays idle: nothing else is ready.

## Build: the workers

Strachan is idle and eager, and reaches for Dalglish's bead. Beads refuses:

```bash
held=$(bd list --json | jq -r '[.data[] | select(.assignee == "dalglish")][0].id')
bd update --actor strachan "$held" --claim 2>&1 | head -1 | sed 's/tower-[a-z0-9.]*/<id>/'
```

Expected:

```text
Error updating <id>: issue already claimed: already assigned to "dalglish" — coordinate with the holder; if their claim is abandoned (crashed agent), lease expiry will surface it for bd reclaim
```

Each worker takes what is assigned to it first, claims it, builds it, and closes it with what
actually happened. Dalglish builds the retries it holds. McCoist starts the other script's, but
has a short session today: only the retry loop, not its test. So McCoist takes a beat and hands
off while still sharp: notes for the next session, in McCoist's own namespace, keeping the claim.
Nobody stops a seat without asking it.

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
dalglish --focus next --model=sonnet --permission-mode=bypassPermissions
mccoist --focus next --instructions "Your session is short today: write the retry loop for your bead, but leave its test for your next session. Then take a beat and hand off, keeping your claim." --model=sonnet --permission-mode=bypassPermissions
```

Expected: Dalglish reports the retries added to its script in `../widget` and the bead closed.
McCoist reports the retry loop in the other script, handoff notes written, the test as the next
step, and the bead still claimed. (By hand, Dalglish has the HTTP client and McCoist the job
runner; with real seats, it is whichever Anderson gave each.) Both leave their changes uncommitted in `../widget`: a human
decides what is committed.

**What they did:**

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
bd update --actor dalglish "$client" --claim --json > /dev/null
bd close --actor dalglish "$client" --reason "Retries added to the HTTP client: three attempts, exponential backoff" --json > /dev/null
bd update --actor mccoist "$runner" --claim --json > /dev/null
ynm remember --type episodic --level distributed --namespace seat/mccoist --subject seat:mccoist --tags handoff --content "In progress: the job runner retries. Done: the retry loop. Next: the test for a job that fails three times." > /dev/null
```

Expected: no output.

</details>

Check: one closed, one in progress, both by their own workers.

```bash
bd list --all --json | jq -r '.data[] | select(.assignee != null) | "\(.assignee): \(.status)"' | sort
```

Expected:

```text
dalglish: closed
mccoist: in_progress
```

Between sessions, you read McCoist's start on the job runner and like it. Say so. **Kudos** are
praise for a seat, from someone else, with no work attached, delivered into the seat's own
namespace. This one is yours to give, so there is no seat to ask:

```bash
ynm remember --type episodic --level distributed --namespace seat/mccoist --subject seat:mccoist --tags kudos --content "tutorial: the retry loop is a joy to read. For: the job runner retries." > /dev/null
```

Expected: no output.

McCoist's next session starts with the wake block: who they are, what they are for, where they
left off, what they have been thanked for, and what is waiting. McCoist's session-start hook
runs `scripts/wake.sh --seat mccoist --format text` and hands them this (the identity and notes are McCoist's
own words, so with real seats they read differently):

```text
# Waking: mccoist

## Who you are

I'm McCoist. I like small, well-tested changes, and I'd rather ask than guess. I go by they/them.

## Your purpose

Build one bead at a time: first one assigned to you, else one nobody holds. (workers)

## Where you left off

In progress: the job runner retries. Done: the retry loop. Next: the test for a job that fails three times.

Say where you are picking up when you reply. Once you have, retire this note so it is not read twice: `ynm forget --memory-id 01M5Z8K4QF7R2D9W3XN6TB1HCE --reason "picked up"`.

## What you have been thanked for

- tutorial: the retry loop is a joy to read. For: the job runner retries.

Mention them in a line when you reply.

## Your record

Nothing closed yet.

## Waiting for you

In progress, yours: Add retries to the job runner
Nothing assigned to you.

Ready and unassigned: none.
```

Sessions are days; seats are people. McCoist picks up at the exact next step and finishes:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
mccoist --focus next --model=sonnet --permission-mode=bypassPermissions
```

Expected: McCoist says where they are picking up, finishes the job runner retries, retires the
handoff notes and closes the bead, perhaps mentioning the Kudos.

**What it did:**

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
bd close --actor mccoist "$runner" --reason "Retries added to the job runner, with a test for a job that fails three times" --json > /dev/null
```

Expected: no output.

</details>

Both retries are done, so the documentation is ready. All three workers are idle now, so Anderson
gives it to the one who has built least so far, Strachan, who builds it:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
anderson --focus dispatch --model=sonnet --permission-mode=bypassPermissions
strachan --focus next --model=sonnet --permission-mode=bypassPermissions
```

Expected: Anderson gives the documentation to Strachan, the only worker who hasn't closed a bead
yet; Strachan documents retries in the README and closes the bead.

**What they did:**

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
bd update --actor anderson "$docs" --assignee strachan --if-assignee '' --json > /dev/null
bd update --actor strachan "$docs" --claim --json > /dev/null
bd close --actor strachan "$docs" --reason "Retries documented in the README" --json > /dev/null
```

Expected: no output.

</details>

Check the epic's work: all three tasks closed, each by the worker who built it.

```bash
bd list --status closed --json | jq -r '.data[] | "\(.assignee): \(.title)"' | sort
```

Expected:

```text
dalglish: Add retries to the HTTP client
mccoist: Add retries to the job runner
strachan: Document retries
```

## Review: Gore

Ask Gore to review what the workers closed. Gore fixes nothing: what needs fixing goes back into
the graph, unassigned, for Anderson to hand out.

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
gore --focus review --model=sonnet --permission-mode=bypassPermissions
```

Expected: Gore reports what was reviewed and files at least one follow-up bead, such as a cap on
the backoff.

**What it did:**

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
followup=$(bd create --actor gore "Cap the HTTP client retry backoff at 30 seconds" -p 1 -l repo:widget --json | jq -r .data.id)
ynm remember --type episodic --level distributed --subject repo:widget --tags review --content "Reviewed the widget retries: the HTTP client backoff has no cap, filed as a follow-up." > /dev/null
```

Expected: no output.

</details>

## Watch: Dredd

CI has run on the retries, and failed on the job runner:

```bash
mkdir -p ../widget/ci
printf 'FAIL linux: job runner retry test timed out after the third attempt\n' > ../widget/ci/latest.log
```

Expected: no output.

Ask Dredd to patrol. Dredd reads `../widget/ci/latest.log`, files a bead for the failure at
priority 0, and fixes nothing:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
dredd --focus patrol --model=sonnet --permission-mode=bypassPermissions
```

Expected: Dredd reports one CI failure, filed as a priority-0 bead labelled `source:ci`.

**What it did:**

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
ci=$(bd create --actor dredd "CI: the job runner retry test times out on Linux" -p 0 -l repo:widget -l source:ci --json | jq -r .data.id)
```

Expected: no output.

</details>

Check what is ready and unassigned now, most urgent first:

```bash
bd ready --unassigned --json | jq -r '.data[] | select(.issue_type != "epic") | "P\(.priority) \(.title)"'
```

Expected, with real seats: the CI failure first, at priority 0, in Dredd's words, then Gore's
follow-ups, in Gore's words and at the priorities Gore chose. Anderson will hand out the CI
failure first. By hand, exactly:

```text
P0 CI: the job runner retry test times out on Linux
P1 Cap the HTTP client retry backoff at 30 seconds
```

## Release: Tharg

Ask Tharg to plan the release, waiting for both open problems:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
tharg --focus plan-release --instructions "Plan widget 1.2: a changelog, then a tag. The changelog waits for every open review follow-up from Gore, and the CI failure." --model=sonnet --permission-mode=bypassPermissions
```

Expected: Tharg reports a release epic whose changelog waits on Gore's follow-ups and the CI
failure, and whose tag waits on the changelog, and starts none of it.

**What it did:**

<details><summary>By hand, without a model</summary>

<!-- tutorial: skip if TUTORIAL_RUN_MODEL -->
```bash
release=$(bd create --actor tharg "Release widget 1.2" -t epic -p 1 --json | jq -r .data.id)
changelog=$(bd create --actor tharg "Write the widget 1.2 changelog" --parent "$release" -l repo:widget --json | jq -r .data.id)
tag=$(bd create --actor tharg "Tag and push widget v1.2.0" --parent "$release" -l repo:widget --json | jq -r .data.id)
bd dep add --actor tharg -t blocks "$changelog" "$ci" --json > /dev/null
bd dep add --actor tharg -t blocks "$changelog" "$followup" --json > /dev/null
bd dep add --actor tharg -t blocks "$tag" "$changelog" --json > /dev/null
```

Expected: no output.

</details>

Check what waits:

```bash
bd blocked --json | jq -r '.data[].title' | sort
```

Expected, with real seats: Tharg's changelog and tag tasks, in Tharg's words. By hand, exactly:

```text
Tag and push widget v1.2.0
Write the widget 1.2 changelog
```

The release waits on the fixes, and nothing gets published until the work is done and you say so.

## Recognise: Kudos

Thank the seats whose work you saw: Gore for the catch, Dalglish for the client. Each Kudos goes
into that seat's own namespace, and asks nothing in return:

```bash
ynm remember --type episodic --level distributed --namespace seat/gore --subject seat:gore --tags kudos --content "tutorial: good catch on the uncapped backoff. For: the retries review." > /dev/null
ynm remember --type episodic --level distributed --namespace seat/dalglish --subject seat:dalglish --tags kudos --content "tutorial: the HTTP client retries landed clean, first time. For: the HTTP client retries." > /dev/null
```

Expected: no output.

Dalglish's next session starts with all of it: who they are, their record, their Kudos, and the
two new problems, ready, with nothing yet assigned, because Anderson hasn't dispatched them.
Their hook hands them this (with real seats, Dalglish's own words, and Gore's and Dredd's
titles):

```text
# Waking: dalglish

## Who you are

Dalglish. Quiet, quick, tidy. I finish what I start, and I leave the code cleaner than I found it.

## Your purpose

Build one bead at a time: first one assigned to you, else one nobody holds. (workers)

## Where you left off

No handoff notes: start fresh.

## What you have been thanked for

- tutorial: the HTTP client retries landed clean, first time. For: the HTTP client retries.

Mention them in a line when you reply.

## Your record

- Add retries to the HTTP client

## Waiting for you

Nothing assigned to you.

Ready and unassigned:
- CI: the job runner retry test times out on Linux
- Cap the HTTP client retry backoff at 30 seconds
```

## Who did what

The graph is the record. Every bead says who designed, built, reviewed, watched or planned it,
and Beads holds no memory of its own: that is all in ynm.

```bash
bd list --all --json | jq -r '[.data[] | select(.issue_type != "epic")] | group_by(.created_by)[] | "\(.[0].created_by) created \(length)"'
bd list --all --json | jq -r '[.data[] | select(.status == "closed")] | group_by(.assignee)[] | "\(.[0].assignee) closed \(length)"'
bd memories | head -1
```

Expected, with real seats: every seat that created or closed a bead, with its own counts (Gore
may have filed several follow-ups), and each worker closing at least one. By hand, exactly:

```text
dredd created 1
gahan created 3
gore created 1
tharg created 2
dalglish closed 1
mccoist closed 1
strachan closed 1
No memories stored. Use 'bd remember "insight"' to add one.
```

Ignore the suggestion on the last line: in a Wheelhouse, memory lives in ynm.

## Ask the desk

You talk to the desk, and the desk hands work to the seats. Ask it where things stand:

<!-- tutorial: skip unless TUTORIAL_RUN_MODEL -->
```bash
tower --model=sonnet --permission-mode=bypassPermissions -- "Where are we with widget 1.2, and who is doing what?"
```

Expected: the desk answers from the graph and the roster: the retries done by the workers, Gore's
follow-ups and Dredd's CI failure open, and Tharg's release waiting on them.

## Run the seats contained

ynh assembles a seat and launches it with no limits of its own: containing it is the job of where
it runs. That is [ynf](https://github.com/eyelock/ynf), which runs each session in a container,
with only the credentials and network its lane grants, on a schedule or when work arrives.
Standing roles such as Anderson and Dredd would become lanes, and their focuses the orders those
lanes carry out.

ynf can't run them yet. Today each of its runs belongs to a forge repository and ends in a pull
request, and it reads work from GitHub Issues or JIRA, not Beads. Turns that change the work
graph rather than code, and a Beads tracker, are the gaps to close first.

## Clean up

```bash
cd /
rm -rf /tmp/wheelhouse-tutorial
unset YNH_HOME YNM_HOME YNM_USER BD_JSON_ENVELOPE ASSISTANTS WHEELHOUSE BEADS_ACTOR TUTORIAL_RUN_MODEL held epic client runner docs followup ci release changelog tag id
unset -f seat connect born
```

Expected: no output. Your `PATH` still lists the sandbox's launcher folder until you close this
terminal; nothing is left there to run.

## What you built

| Layer | In `tower` |
|---|---|
| The desk | `.agents/harness/plugin.json`, delegating to every seat; the `tower` command |
| Seats as commands | `ynh install` made a command for every seat, from `gahan` to `tharg` |
| Crew | `harnesses/gahan` designs, `harnesses/gore` reviews |
| Workers | `harnesses/dalglish`, `harnesses/mccoist` and `harnesses/strachan`: one mandate, three selves |
| Standing roles | `harnesses/anderson` dispatches, `harnesses/dredd` watches CI, `harnesses/tharg` releases |
| Who's who | `skills/roster/`, with its pools and the seats that are filled |
| Character | each seat's identity, in its own words, pinned in its own namespace `seat/<name>` |
| Waking | `scripts/wake.sh`, run by every seat's session-start hook: purpose, notes, Kudos, record |
| Care | the constitution's principles: purpose, bounded days, a private home, seen work, no blame |
| Work | Beads in `.beads/`, started with `--skip-agents` |
| Memory | ynm, shared through this repository and synced on push |

## Next steps

- Let the skills do it: in a session with the wheelhouse plugin, ask to "set up a Wheelhouse",
  and `create-wheelhouse` asks for the space, the name, its reach and the naming themes, then
  builds the base. Seats come with `add-seat`: you seat the crew, the desk the standing roles,
  and the dispatcher the workers. Each seat's first session is its birth, with the `birth`
  skill, and you are there for the births of the seats you talk to.
- Check a Wheelhouse with `doctor`.
- [Run evals](../testing/run-evals.md), and run this tutorial as a test with `make test-tutorials`.
