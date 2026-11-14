---
"@eyelock-assistants/wheelhouse": patch
---

Two refresh eval assertions now match the skill: the workspace-trust case checks for no `ynh trust accept` (refresh itself runs `ynh trust ls`), and the docs-only case allows the `seatsNotReady` report the skill makes on every run while still failing a reinstall, trust or restart the diff did not need.

The refresh skill also says the dry run only previews and skips the doctor, and that a request to apply what changed means running the real pass too: a live run had stopped after the dry run and reported "the doctor was skipped".
