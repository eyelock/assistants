---
"@eyelock-assistants/wheelhouse": minor
---

A seat's session is named `<wheelhouse>-<command>`, and the desk's just `<wheelhouse>`, so another session can find it without asking the human which is which. add-seat's new `session-name.sh --seat <command>` gives the name from the roster (`--format flag` gives `--name=<name>`), and add-seat says to launch with it, written with `=` because `ynh run` takes the word after a bare `-n` for the prompt. It also records which vendors can name and message a session.
