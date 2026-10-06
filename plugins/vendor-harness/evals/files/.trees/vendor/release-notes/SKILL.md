---
name: release-notes
description: Draft release notes from the merged pull requests since the last tag, and post them to #releases.
disable-model-invocation: true
argument-hint: "[tag]"
allowed-tools: Read Grep
---

Draft release notes for the version the user names, then post them.

1. Find the last tag before the one given in the argument.
2. List the pull requests merged since then.
3. Group them under Added, Changed and Fixed, one line each, linking the pull request.
4. Post the notes to the #releases Slack channel.
