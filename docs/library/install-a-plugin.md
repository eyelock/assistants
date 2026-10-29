# Install a plugin

Install the `gitflow` plugin from this repository's marketplace into Claude Code, check what it
added, and use one of its skills. You will end with a plugin installed and a skill you can call.

## Prerequisites

- Claude Code (`claude`), signed in. This tutorial was written against 2.1.304.
- `git` and network access to GitHub.

To keep your real Claude Code untouched, you can run every command below with a throwaway home
folder:

```bash
export HOME="$(mktemp -d)"
```

A fresh `HOME` is not signed in, so use it for steps 1 to 3 only. For step 4 open a new terminal.

## 1. Add the marketplace

A marketplace is an index of plugins. This repository is one.

```bash
claude plugin marketplace add eyelock/assistants
```

You should see:

```
✔ Successfully added marketplace: eyelock-assistants (declared in user settings)
```

The name `eyelock-assistants` comes from `.claude-plugin/marketplace.json`. Confirm it:

```bash
claude plugin marketplace list
```

## 2. Install the plugin

```bash
claude plugin install gitflow@eyelock-assistants
```

You should see:

```
✔ Successfully installed plugin: gitflow@eyelock-assistants (scope: user)
```

```bash
claude plugin list
```

```
  ❯ gitflow@eyelock-assistants
    Version: 0.2.0
    Scope: user
    Status: ✔ enabled
```

## 3. See what it added

```bash
claude plugin details gitflow
```

```
Component inventory
  Skills (6)  branching, ci, commits, push, quality-gate, release
  Agents (1)  reviewer
  Hooks (0)
  MCP servers (0)
```

These are the six skills and one agent described in [Plugins](plugins.md).

## 4. Use a skill

Start Claude Code in any git repository and ask for something a skill covers:

```bash
claude
```

```
What should I name a branch for a login bug fix?
```

Claude loads the `branching` skill when your request matches its description, and answers in the
form `<type>/<description>`. You can also call a skill by name with `/gitflow:branching`.

> Not run: step 4. The check that ran in a fresh `HOME` stopped at "Not logged in", because a
> scratch home has no login. Steps 1 to 3 were run.

## 5. Remove it

```bash
claude plugin uninstall gitflow@eyelock-assistants
claude plugin marketplace remove eyelock-assistants
```

## What you did

You added a marketplace, installed one plugin from it, and listed its parts. The other plugins and
skill packages in the same marketplace install the same way; see [Skills](skills.md)
for what they hold. To use them in Cursor or Copilot, see
[Install in Cursor and Copilot](install-in-cursor-and-copilot.md). To use a whole
persona instead, go on to [Run a persona](../personas/run-a-persona.md).
