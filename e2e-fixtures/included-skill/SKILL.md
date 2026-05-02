---
name: included-skill
description: A no-op skill used as the include target for ynh E2E include/delegate tests.
---

# included-skill

This skill is intentionally trivial. Its only purpose is to be a stable,
small, non-empty directory under `eyelock/assistants:e2e-fixtures/` that
the include/delegate fixtures can point at. Tests assert that a fetch of
this directory completes and that the resolved SHA in `installed.json`
matches the pinned commit.
