# Build a persona harness

Compose a harness from skills that already exist in this repo, give it a profile that changes its voice, and give it a focus so one command does one job. You will build a code-review persona called `reviewer`, check it, look at what it assembles to, and run it once on a staged change.

No skill is written here. A persona is a recipe: which skills to include, which variant to switch on, and what to ask for. The `ynh/david`, `ynh/planner` and `ynh/tester` harnesses in this repo are built the same way.

## Prerequisites

- `ynh` and `ynd` v0.12.0, on your PATH
- Claude Code (`claude`), signed in
- `git`
- macOS or Linux

```bash
ynh --version
```

You should see:

```
v0.12.0
```

One step below runs a model, once, with `--model=sonnet`. It makes one paid Claude request of a few turns.

## Make a workspace

Everything goes in one folder, and `YNH_HOME` keeps ynh's own state inside it, so your real `~/.ynh` is untouched.

```bash
rm -rf /tmp/assistants-persona
mkdir -p /tmp/assistants-persona
cd /tmp/assistants-persona
export YNH_HOME=/tmp/assistants-persona/home
git clone https://github.com/eyelock/assistants.git
ynh init
```

You should see:

```
ynh home: /tmp/assistants-persona/home

Add this to your shell profile if not already present:
  export PATH="/tmp/assistants-persona/home/bin:$PATH"
```

Ignore the PATH suggestion. The clone gives the harness a local copy of this repo's skills to include. Keep `YNH_HOME` exported in this terminal for every step that follows.

## Choose the skills

Look at what is available.

```bash
ls assistants/skills/dev/skills assistants/skills/voice/skills
```

You should see:

```
assistants/skills/dev/skills:
dev-backend
dev-debug
dev-project
dev-quality
dev-review
dev-security
dev-ui
docs-sync
gh-cli
skill-creator

assistants/skills/voice/skills:
reply-styles
voice
voice-direct
voice-formal
voice-warm
```

The reviewer takes two skills from `skills/dev` (`dev-review` and `dev-security`) and three from `skills/voice` (`voice`, `voice-direct` and `reply-styles`, so its feedback is brief). A fourth voice, `voice-warm`, will come in through a profile.

## Write the harness

A harness is one file, `.agents/harness/plugin.json`. Each `includes` entry names a source (`git`), a `path` inside it and, optionally, a `pick` of skills. Without `pick` you get every skill at that path.

```bash
mkdir -p /tmp/assistants-persona/reviewer/.agents/harness

cat > /tmp/assistants-persona/reviewer/.agents/harness/plugin.json << 'EOF'
{
  "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
  "name": "reviewer",
  "version": "0.1.0",
  "description": "A code-review persona: review and security skills, answered in a direct voice",
  "default_vendor": "claude",
  "includes": [
    {
      "git": "/tmp/assistants-persona/assistants",
      "path": "skills/dev",
      "pick": ["skills/dev-review", "skills/dev-security"]
    },
    {
      "git": "/tmp/assistants-persona/assistants",
      "path": "skills/voice",
      "pick": ["skills/voice", "skills/voice-direct", "skills/reply-styles"]
    }
  ],
  "profiles": {
    "kind": {
      "includes": [
        {
          "git": "/tmp/assistants-persona/assistants",
          "path": "skills/voice",
          "pick": ["skills/voice-warm"]
        }
      ]
    }
  },
  "focuses": {
    "review-staged": {
      "prompt": "Use the dev-review skill to review the staged changes in this repository. Report findings, most serious first."
    },
    "review-kindly": {
      "prompt": "Use the dev-review skill to review the staged changes in this repository, and write the feedback in a warm voice.",
      "profile": "kind"
    }
  }
}
EOF
```

Three ideas are in that file.

- **Includes** compose the persona. The `git` values here are your local clone, so nothing is fetched. The repo's own personas use `https://github.com/eyelock/assistants` instead; that is the only difference.
- **A profile** is a named variant. `kind` declares only what it adds: one more include, appended to the base. It cannot remove a base include.
- **A focus** pairs a prompt with an optional profile, and is the unit you run: `review-kindly` means "the `kind` profile, and this prompt".

## Check it

`ynd validate` checks the manifest against ynh's schema and the structure around it. `ynd lint` checks the files for common problems.

```bash
ynd validate /tmp/assistants-persona/reviewer
ynd lint /tmp/assistants-persona/reviewer
```

You should see (validate trimmed):

```
/tmp/assistants-persona/reviewer: valid
  checked:
    manifest     .../reviewer/.agents/harness/plugin.json against https://eyelock.github.io/ynh/schema/plugin.schema.json
    includes     /tmp/assistants-persona/assistants path skills/dev pick skills/dev-review, skills/dev-security
                 /tmp/assistants-persona/assistants path skills/voice pick skills/voice, skills/voice-direct, skills/reply-styles
    mcp_servers  none
    hooks        none
    profiles     kind
    focuses      review-kindly
                 review-staged
    ...
Checked 1 file(s) — no issues found.
```

Validate lists the includes but does not fetch them or confirm the picked skills exist. Preview, next, does.

## See what the assistant will be given

Preview assembles the harness for Claude without starting it. Do it three ways: as it is, with the profile, and through the focus.

```bash
ynd preview /tmp/assistants-persona/reviewer -v claude -o /tmp/assistants-persona/p-base
ynd preview /tmp/assistants-persona/reviewer -v claude --profile kind -o /tmp/assistants-persona/p-kind
ynd preview /tmp/assistants-persona/reviewer -v claude --focus review-kindly -o /tmp/assistants-persona/p-focus
ls /tmp/assistants-persona/p-base/.claude/skills
echo ---
ls /tmp/assistants-persona/p-kind/.claude/skills
echo ---
ls /tmp/assistants-persona/p-focus/.claude/skills
```

You should see:

```
Preview written to /tmp/assistants-persona/p-base
Preview written to /tmp/assistants-persona/p-kind
Preview written to /tmp/assistants-persona/p-focus
dev-review
dev-security
reply-styles
voice
voice-direct
---
dev-review
dev-security
reply-styles
voice
voice-direct
voice-warm
---
dev-review
dev-security
reply-styles
voice
voice-direct
voice-warm
```

The profile added `voice-warm`, and the focus switched the same profile on for you. Preview is where you catch a wrong `pick` or a missing include.

## Run it

You need something to review. Make a repository with one staged change that has a flaw to find.

```bash
mkdir -p /tmp/assistants-persona/demo && cd /tmp/assistants-persona/demo
git init -q
git config user.email you@example.com && git config user.name you

cat > users.js << 'EOF'
export function findUser(db, name) {
  return db.query("SELECT * FROM users WHERE name = '" + name + "'");
}
EOF
git add . && git commit -qm "feat: add findUser"

cat > users.js << 'EOF'
export function findUser(db, name) {
  return db.query("SELECT * FROM users WHERE name = '" + name + "' LIMIT 1");
}

export function deleteUser(db, id) {
  db.query("DELETE FROM users WHERE id = " + id);
}
EOF
git add users.js
git diff --staged --stat
```

You should see:

```
 users.js | 6 +++++-
 1 file changed, 5 insertions(+), 1 deletion(-)
```

Now run the `review-kindly` focus. `--allowedTools` lets the model run read-only git commands and read files without a prompt, since no one is at the keyboard in a focus run. `< /dev/null` stops Claude Code waiting three seconds for stdin.

*Your output will differ: it shows what the model did.*

```bash
ynh run /tmp/assistants-persona/reviewer \
  --focus review-kindly \
  --model=sonnet \
  --allowedTools="Bash(git diff:*),Bash(git status:*),Read" < /dev/null
```

You should see something like this (trimmed with `...`; the first lines are ynh resolving the includes):

```
Resolving 3 include(s)...
  Cached /tmp/assistants-persona/assistants → skills/dev [skills/dev-review, skills/dev-security]
  Cached /tmp/assistants-persona/assistants → skills/voice [skills/voice, skills/voice-direct, skills/reply-styles]
  Cached /tmp/assistants-persona/assistants → skills/voice [skills/voice-warm]
Launching claude...
Thanks for putting `deleteUser` together. Keeping it next to `findUser` makes sense, and the `LIMIT 1` is a good instinct for a single-user lookup. I found a few things to fix before this merges.

**users.js**

- `users.js:2` | critical | `findUser` still builds SQL by concatenating `name`. Why it matters: a name like `' OR '1'='1` changes the query ... Fix: use a parameterized query, e.g. `db.query("SELECT * FROM users WHERE name = ? LIMIT 1", [name])`.
- `users.js:6` | critical | `deleteUser` concatenates `id` into a `DELETE`. Why it matters: `id` of `"1 OR 1=1"` deletes every user ...
- `users.js:5-7` | warning | `deleteUser` has no authorization check, doesn't return the query result ...
- `users.js:2,5` | warning | There are no tests for the `LIMIT 1` change or for `deleteUser` ...

I'm happy to help write the parameterized versions and tests if that would be useful.

**Request changes**
```

Read it for three things. The opening names something specific the author did, as `voice-warm` asks. The findings come as location, severity, why it matters and fix, as `dev-review` asks. And the SQL injection is found, which is `dev-security`'s ground. Skills you did not write worked together because the harness named them.

To hear the direct voice instead, run `--focus review-staged`. A focus and `--profile` cannot be used on the same command: the focus already names its profile.

## Clean up

```bash
cd /tmp
rm -rf /tmp/assistants-persona
unset YNH_HOME
```

## What you learned

- A persona is a `plugin.json` that composes skills with `includes` and `pick`; you wrote no skill
- A profile adds to the base (here, a voice) and is chosen with `--profile`
- A focus pairs a prompt with a profile, so `--focus` runs one job the same way each time
- `ynd validate` and `ynd lint` check the files; `ynd preview` shows what the assistant receives

## Next

- Give a harness something to act on: [Give a harness a tool](../harnesses/give-a-harness-a-tool.md)
- Write a skill of your own to include: [Write a skill with evals](../library/write-a-skill-with-evals.md)
- Every field in the file: [Harness manifest](../harnesses/harness-manifest.md)
