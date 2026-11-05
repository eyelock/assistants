# Run a persona

Install the `planner` persona with `ynh`, look at what it is made of, and run it once. A persona
is a harness that composes skills for one kind of work; `planner` is for architecture and
implementation planning.

## Prerequisites

- `ynh` v0.12.0 on your `PATH`.
- Claude Code (`claude`), signed in. `planner` uses `claude` as its default vendor.
- `git` and network access to GitHub.

```bash
ynh --version
```

```
v0.12.0
```

## 1. Keep ynh's state in a scratch folder

`YNH_HOME` is where ynh keeps installed harnesses. Point it at a new folder so your real `~/.ynh`
stays untouched.

```bash
export YNH_HOME="$(mktemp -d)"
ynh init
```

`ynh init` prints the home path and the `PATH` line for its launchers. You do not need the
launchers here, because `ynh run` works without them.

## 2. Install the persona

```bash
ynh install github.com/eyelock/assistants --path ynh/planner
```

```
Fetching 2 include(s) and 0 delegate(s)...
Installed harness "planner"
```

The persona is the directory `ynh/planner` in this repository. ynh fetched the two skill
packages it includes.

```bash
ynh ls
```

The id of the harness is `github.com/eyelock/assistants/planner`. Use the full id from here on.

## 3. Look inside

```bash
ynh info github.com/eyelock/assistants/planner
```

```
Includes:
  https://github.com/eyelock/assistants  path=skills/dev  pick=[skills/dev-project, skills/dev-review]
  https://github.com/eyelock/assistants  path=skills/infra  pick=[skills/gh-os-repo]
MCP Servers:
  (none)
```

A persona is a list of skills to pick from the shared library, and no server. That is the whole of
`planner`: `dev-project`, `dev-review` and `gh-os-repo`. See [Persona harnesses](harnesses.md)
for the others.

## 4. Run it

Run it in an empty folder, once, with the `sonnet` model. Everything after the harness id is
passed to `claude`, so `-p` makes it a one-shot, non-interactive run.

```bash
mkdir -p planner-try && cd planner-try
ynh run github.com/eyelock/assistants/planner --model=sonnet -p "In two sentences, which skills do you have available?"
```

```
Resolving 2 include(s)...
  Cached eyelock/assistants → skills/dev [skills/dev-project, skills/dev-review]
  Cached eyelock/assistants → skills/infra [skills/gh-os-repo]
Launching claude...
```

The reply that follows lists `dev-project`, `dev-review` and `gh-os-repo`. It also lists skills
from your own Claude Code setup, such as built-in ones, because ynh adds to your vendor
configuration and does not replace it.

To work with it instead, leave out `-p`: `ynh run github.com/eyelock/assistants/planner`.

## 5. Clean up

```bash
ynh uninstall github.com/eyelock/assistants/planner
```

Deleting the scratch `YNH_HOME` folder removes everything else the tutorial made.

## What you did

You installed a persona from a marketplace-style source, read its includes, and ran it with a
named model. To run the read-only platform harnesses, which also need credentials, see
[Connect a platform](../triage/connect-a-platform.md) and
[Ask a triage question](../triage/ask-a-triage-question.md).
