---
"@eyelock-assistants/wheelhouse": minor
---

A seat's session is named `<wheelhouse>-<command>`, and the desk's just `<wheelhouse>`, so another session can find it without asking the human which is which. add-seat's new `session-name.sh --seat <command>` gives the name from the roster (`--format flag --vendor <vendor>` gives `--name=<name>` on Claude and nothing on a vendor with no checked flag), and add-seat and create-wheelhouse put it in every instruction that starts a seat or the desk, written with `=` because `ynh run` takes the word after a bare `-n` for the prompt. It also records which vendors can name and message a session.
